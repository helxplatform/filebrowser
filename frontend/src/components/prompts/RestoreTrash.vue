<template>
  <div class="card floating">
    <div class="card-title">
      <h2>{{ $t("prompts.restore") }}</h2>
    </div>

    <div class="card-content">
      <p>{{ $t("prompts.restoreMessage") }}</p>
    </div>

    <div class="card-action">
      <button
        class="button button--flat button--grey"
        @click="closeHovers"
        :aria-label="$t('buttons.cancel')"
        :title="$t('buttons.cancel')"
      >
        {{ $t("buttons.cancel") }}
      </button>
      <button
        @click="submit"
        class="button button--flat"
        type="submit"
        :aria-label="$t('buttons.restore')"
        :title="$t('buttons.restore')"
      >
        {{ $t("buttons.restore") }}
      </button>
    </div>
  </div>
</template>

<script>
import { mapActions, mapState, mapWritableState } from "pinia";
import { useFileStore } from "@/stores/file";
import { useLayoutStore } from "@/stores/layout";
import { files as api } from "@/api";

export default {
  name: "restore-trash",
  inject: ["$showError"],
  computed: {
    ...mapState(useFileStore, ["req", "selected"]),
    ...mapWritableState(useFileStore, ["reload"]),
  },
  methods: {
    ...mapActions(useLayoutStore, ["closeHovers"]),
    submit: async function () {
      const resources = this.selected.map((i) => this.req.items[i]);

      try {
        await Promise.all(resources.map((item) => api.restoreFromTrash(item)));
        this.reload = true;
      } catch (e) {
        this.$showError(e);
      }

      this.closeHovers();
    },
  },
};
</script>