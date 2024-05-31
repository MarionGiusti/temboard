<script setup>
/* A Bootstrap dialog
 *
 * Supports temBoard 7.X agent with key.
 */
import { computed, onMounted, reactive, ref } from "vue";

import Error from "../Error.vue";
import ModalDialog from "../ModalDialog.vue";
import UserForm from "./UserForm.vue";

const root = ref(null);
const error = ref(null);
const formCmp = ref(null);
const waiting = ref(false);

const initialState = {
  // User information from API.
  user_groups: [],
};
const state = reactive({ ...initialState });

const groups = computed(() => {
  return Array.from(state.user_groups, (group) => {
    return {
      name: group.name,
      description: group.description,
      disabled: false,
      selected: false,
    };
  });
});

onMounted(() => {
  $.ajax({
    url: "/json/settings/all/group/role",
    type: "get",
    async: true,
    contentType: "application/json",
    dataType: "json",
  })
    .fail((xhr) => {
      waiting.value = false;
      error.value.fromXHR(xhr);
    })
    .done((data) => {
      state.user_groups = data.groups.map((group) => ({
        name: group.name,
        description: group.description,
      }));
    });
});

function register(data) {
  waiting.value = true;
  console.log("DATA NEW", data);
  $.ajax({
    url: "/json/settings/user",
    method: "POST",
    async: true,
    contentType: "application/json",
    dataType: "json",
    data: JSON.stringify({
      ...data,
    }),
  })
    .fail((xhr) => {
      waiting.value = false;
      error.value.fromXHR(xhr);
    })
    .done(() => {
      window.location.reload();
    });
}

function reset() {
  Object.assign(state, initialState);
}
</script>

<template>
  <ModalDialog id="modalNewUser" title="Register New User" v-on:closed="reset" ref="root">
    <!-- Register -->
    <UserForm ref="formCmp" :groups="groups" :waiting="waiting" v-on:submit="register">
      <Error ref="error" :showTitle="false"></Error>
    </UserForm>
  </ModalDialog>
</template>
