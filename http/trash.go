package http

import (
	"bufio"
	"bytes"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"unicode"

	fbErrors "github.com/filebrowser/filebrowser/v2/errors"
	"github.com/filebrowser/filebrowser/v2/files"
)

type TrashFile struct {
	TrashedDate string
	Path        string
}

type RestoreTrashResponse struct {
	RestoredPath string `json:"restored_path"`
}

func getTrashedFilePath(trashFile *files.FileInfo) (string, string, error) {
	infoPath := filepath.Join(filepath.Dir(trashFile.Path), "../info", trashFile.Name+".trashinfo")
	f, err := trashFile.Fs.Open(infoPath)
	if err != nil {
		return "", "", err
	}
	defer f.Close()

	scanner := bufio.NewScanner(f)
	var encodedPath string
	var trashedDate string
	for scanner.Scan() {
		line := scanner.Text()
		if strings.HasPrefix(line, "Path=") {
			encodedPath = strings.TrimSpace(strings.TrimPrefix(line, "Path="))
		}
		if strings.HasPrefix(line, "DeletionDate=") {
			trashedDate = strings.TrimSpace(strings.TrimPrefix(line, "DeletionDate="))
		}
		if encodedPath != "" && trashedDate != "" {
			break
		}
	}

	decodedPath, err := url.QueryUnescape(encodedPath)
	if err != nil {
		return "", "", err
	}
	return decodedPath, trashedDate, nil
}

func getTrashedFiles(trashDir string) ([]TrashFile, error) {
	var trashFiles []TrashFile

	cmd := exec.Command("trash-list", "--trash-dir", trashDir)
	stdout, err := cmd.Output()
	if err != nil {
		return nil, err
	}

	scanner := bufio.NewScanner(bytes.NewReader(stdout))
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())

		if !unicode.IsDigit(rune(line[0])) {
			continue
		}

		fields := strings.Fields(line)
		if len(fields) < 3 {
			continue
		}

		// NOTE: We use a substring match on the path + matching trash dates rather than simply looking for path equality
		// because for some reason trash-restore includes the absolute path (including the volume) whereas .trashinfo
		// omits the volume path in its `Path` value, making it relative. The simplest way to recover the absolute path so that
		// an equality check can be performed is by interfacing with the Python internals of trash-cli, which is convoluted.
		date := fmt.Sprintf("%sT%s", fields[0], fields[1])
		path := strings.Join(fields[2:], " ")
		trashFiles = append(trashFiles, TrashFile{TrashedDate: date, Path: path})
	}

	return trashFiles, nil
}

func restoreFromTrash(trashFile *files.FileInfo) (string, error) {
	// .trashinfo omits the mount point of the trashed file's original path for some reason.
	originalPathNoMount, trashedDate, err := getTrashedFilePath(trashFile)
	if err != nil {
		return "", err
	}

	mountDir, err := files.FindMountPoint(trashFile.RealPath())
	if err != nil {
		return "", err
	}

	absoluteOriginalPath := filepath.Join(mountDir, originalPathNoMount)

	trashDir, err := files.GetAssociatedTrashDir(trashFile.Fs, trashFile.Path)
	if err != nil {
		return "", err
	}
	if trashDir == nil {
		return "", fmt.Errorf("No trash directory exists for the file '%s'.", trashFile.RealPath())
	}

	cmd := exec.Command("sh", "-c", `trash-restore --trash-dir="$1"`, "trash-restore", *trashDir)
	// Trash-restore must be executed under the directory of the original path of the target trash item.
	cmd.Dir = filepath.Dir(absoluteOriginalPath)

	stdinPipe, err := cmd.StdinPipe()
	if err != nil {
		return "", err
	}
	stdoutPipe, err := cmd.StdoutPipe()
	if err != nil {
		return "", err
	}

	if err := cmd.Start(); err != nil {
		return "", err
	}

	// Resolve the correct ID for the trashed file from the entries in trash-restore's stdout
	var restoreId *int
	var wg sync.WaitGroup
	wg.Add(1)
	go func() {
		defer wg.Done()

		terminationSequence := "What file to restore"
		reader := bufio.NewReader(stdoutPipe)
		var lineBuffer strings.Builder
		for {
			b, err := reader.ReadByte()
			if err != nil {
				if err == io.EOF {
					break
				}
				fmt.Println("Read error:", err)
				break
			}

			lineBuffer.WriteByte(b)

			if b == '\n' {
				line := lineBuffer.String()
				lineBuffer.Reset()

				line = strings.TrimSpace(line)

				if !unicode.IsDigit(rune(line[0])) {
					continue
				}

				fields := strings.Fields(line)
				if len(fields) < 4 {
					continue
				}

				id, err := strconv.Atoi(fields[0])
				if err != nil {
					continue
				}

				date := fmt.Sprintf("%sT%s", fields[1], fields[2])
				path := strings.Join(fields[3:], " ")
				matchesPath := strings.TrimSpace(path) == strings.TrimSpace(absoluteOriginalPath)
				// Needs to match date as well in the edge case that there are naming conflicts
				matchesDate := strings.TrimSpace(date) == strings.TrimSpace(trashedDate)
				if matchesPath && matchesDate {
					restoreId = &id
					break
				}

				// The termination sequence immediately follows a newline; once detected, stop reading stdout.
				nextBytes, err := reader.Peek(len(terminationSequence))
				if err == nil && strings.HasPrefix(string(nextBytes), terminationSequence) {
					break
				}
			}
		}
	}()
	wg.Wait()

	if restoreId == nil {
		return "", fmt.Errorf("No trashed entry found for path: %s", absoluteOriginalPath)
	}

	// Pipe the entry identifier for the trashed file to trash-restore.
	if _, err = io.WriteString(stdinPipe, fmt.Sprintf("%d\n", *restoreId)); err != nil {
		return "", err
	}
	stdinPipe.Close()

	if err := cmd.Wait(); err != nil {
		return "", err
	}

	return originalPathNoMount, nil
}

var restoreTrashHandler = withUser(func(w http.ResponseWriter, r *http.Request, d *data) (int, error) {
	if !d.user.Perm.Rename {
		return http.StatusForbidden, fbErrors.ErrPermissionDenied
	}
	file, err := files.NewFileInfo(&files.FileOptions{
		Fs:         d.user.Fs,
		Path:       r.URL.Path,
		Modify:     d.user.Perm.Modify,
		Expand:     false,
		ReadHeader: false,
		Checker:    d,
		Content:    false,
	})
	if err != nil {
		return errToStatus(err), err
	}

	originalPath, err := restoreFromTrash(file)
	if err != nil {
		return errToStatus(err), err
	}

	return renderJSON(w, r, &RestoreTrashResponse{
		RestoredPath: originalPath,
	})
})
