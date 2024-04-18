<script setup>
/**
 * A Bootstrap dialog editing instance properties.
 *
 * Supports temBoard 7.X agent with key.
 */
import { computed, nextTick, onMounted, onUpdated, reactive, ref } from "vue";

import Error from "../Error.vue";
import ModalDialog from "../ModalDialog.vue";
import UserForm from "./UserForm.vue";

const root = ref(null);
const error = ref(null);
const formCmp = ref(null);
const waiting = ref(false);
const initialForm = {
  username: "",
  email: "",
  phone: "",
  password: "",
  password2: "",
  groups: [],
  in_groups: [],
  is_active: "",
  is_admin: "",
};
const form = reactive({ ...initialForm });
let role_name = null;

const groups = computed(() => {
  return Array.from(form.groups, (group) => {
    return {
      name: group.name,
      description: group.description,
      selected: form.in_groups.indexOf(group.name) !== -1,
    };
  });
});

function open(username) {
  console.log("OPEN");
  // Reset dialog state.
  error.value.clear();
  waiting.value = true;

  // Configure for target user data.
  role_name = username;

  fetch_current_data();
}

function fetch_current_data() {
  return $.ajax({
    url: "/json/settings/user/" + role_name,
  })
    .fail((xhr) => {
      waiting.value = false;
      error.value.fromXHR(xhr);
    })
    .done((data) => {
      form.username = data.role_name;
      form.email = data.role_email;
      form.phone = data.role_phone;
      form.in_groups = data.in_groups;
      form.groups = data.groups;
      form.is_active = data.is_active;
      form.is_admin = data.is_admin;
      waiting.value = false;
    });
}

function update(data) {
  console.log("DATA UP", data);
  waiting.value = true;
  $.ajax({
    url: "/json/settings/user/" + form.username,
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
  Object.assign(form, initialForm);
  formCmp.value.teardown_multiselects();
}

defineExpose({ open });
</script>

<template>
  <ModalDialog id="modalUpdateUser" title="Update User" v-on:closed="reset" ref="root">
    <UserForm
      ref="formCmp"
      :username="form.username"
      :email="form.email"
      :phone="form.phone"
      :groups="groups"
      :is_active="form.is_active"
      :is_admin="form.is_admin"
      :waiting="waiting"
      v-on:submit="update"
    >
      <Error ref="error"></Error>
    </UserForm>
  </ModalDialog>
</template>
