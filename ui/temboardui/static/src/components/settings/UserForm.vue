<script setup>
import { nextTick, onMounted, onUpdated, ref } from "vue";

const props = defineProps([
  "waiting", // Whether parent is interacting with server.
  "groups",
]);

const root = ref(null);

onMounted(() => {
  $('[data-toggle="tooltip"]', root.value.$el).tooltip();
});

onUpdated(() => {
  if (!$("#selectGroups").data("multiselect")) {
    nextTick(setup_multiselects);
  }
  if ($("#selectGroups").data("multiselect")) {
    $("#selectGroups").multiselect(props.waiting ? "disable" : "enable");
  }
});

function setup_multiselects() {
  // jQuery multiselect plugin must be called once Vue template is rendered.
  const multiselectOptions = {
    templates: {
      button: `
            <button type="button"
                    class="multiselect dropdown-toggle border-secondary"
                    data-toggle="dropdown">
              <span class="multiselect-selected-text"></span> <b class="caret"></b>
            </button>
            `,
      li: `
            <li class="dropdown-item">
              <a href="javascript:void(0);"><label></label></a>
            </li>
            `,
    },
    numberDisplayed: 1,
  };
  $("#selectGroups").multiselect(multiselectOptions);
}

function teardown_multiselects() {
  $("#selectGroups").multiselect("destroy");
}

function submit() {
  // data generates payload for POST /json/settings/users
  const data = {
    // Define parameters.
    new_username: $("#inputNewUsername").val(),
    email: $("#inputEmail").val(),
    phone: $("#inputPhone").val(),
    password: $("#inputPassword").val(),
    password2: $("#inputPassword2").val(),
    groups: $("#selectGroups").val(),
    is_active: $("#switchActive").is(":checked"),
    is_admin: $("#switchAdmin").is(":checked"),
  };
  emit("submit", data);
}

const emit = defineEmits(["submit"]);
defineExpose({ setup_multiselects, teardown_multiselects });
</script>

<template>
  <form id="formAddUser" v-on:submit.prevent="submit" ref="root">
    <div class="modal-body p-3">
      <div class="row" v-if="$slots.default">
        <div class="col">
          <!-- Error slot -->
          <slot></slot>
        </div>
      </div>

      <div class="row">
        <div class="form-group col-sm-6">
          <label for="inputNewUsername" class="control-label">Username</label>
          <input type="text" class="form-control" id="inputNewUsername" placeholder="Username" />
        </div>
        <div class="form-group col-sm-6">
          <label for="inputEmail" class="control-label">Email</label>
          <input type="email" class="form-control" id="inputEmail" placeholder="Email" />
          <span class="form-text text-muted small"
            >Leave blank to prevent user from receiving notifications by email.</span
          >
        </div>
      </div>

      <div class="row">
        <div class="form-group col-sm-6">
          <label for="inputPassword" class="control-label">Password&#42;</label>
          <input type="password" class="form-control" id="inputPassword" placeholder="Password" />
          <input type="password" class="form-control" id="inputPassword2" placeholder="Confirm password" />
          <p class="form-text text-muted"><small>&#42;: leave this field blank to keep it unchanged.</small></p>
        </div>

        <div class="form-group col-sm-6" v-if="groups.length > 0">
          <label for="selectGroups" class="control-label">Groups</label><br />
          <select id="selectGroups" :disabled="waiting" multiple>
            <option
              v-for="group in groups"
              :key="group.name"
              :selected="group.selected ? 'selected' : null"
              :value="group.name"
              :title="group.description"
            >
              {{ group.name }}
            </option></select
          ><br />
          <div class="custom-control custom-switch">
            <br />
            <input type="checkbox" class="custom-control-input" id="switchActive" checked />
            <label class="custom-control-label" for="switchActive">Active</label><br />
          </div>
          <div class="custom-control custom-switch">
            <br />
            <input type="checkbox" class="custom-control-input" id="switchAdmin" />
            <label class="custom-control-label" for="switchAdmin">Administrator</label><br />
          </div>
        </div>
      </div>

      <div class="row">
        <div class="form-group col-sm-6">
          <label for="inputPhone" class="control-label">Phone</label>
          <input type="text" class="form-control" id="inputPhone" placeholder="Phone" />
          <span class="form-text text-muted small"
            >Leave blank to prevent user from receiving notifications by SMS.</span
          >
        </div>
      </div>

      <div class="modal-footer">
        <button type="button" class="btn btn-outline-secondary" data-dismiss="modal">Cancel</button>
        <button type="submit" id="submitFormAddUser" class="btn btn-success">Save</button>
      </div>
    </div>
  </form>
</template>
