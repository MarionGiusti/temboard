import Vue from "vue";

import NewUserWizard from "./components/settings/NewUserWizard.vue";
import UpdateUserDialog from "./components/settings/UpdateUserDialog.vue";

new Vue({
  el: "#app",
  components: {
    "new-user-wizard": NewUserWizard,
    "update-user-dialog": UpdateUserDialog,
  },
});
