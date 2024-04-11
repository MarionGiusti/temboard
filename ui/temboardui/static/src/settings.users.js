import Vue from "vue";

import NewUserWizard from "./components/settings/NewUserWizard.vue";

new Vue({
  el: "#app",
  components: {
    "new-user-wizard": NewUserWizard,
  },
});
