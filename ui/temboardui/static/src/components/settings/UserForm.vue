<script setup>
import { nextTick, onMounted, onUpdated, ref } from "vue";

const props = defineProps([
  "waiting", // Whether parent is interacting with server.
  "username",
  "email",
  "phone",
  "groups",
  "is_active",
  "is_admin",
]);

const root = ref(null);
const selectGroups = ref([]);
const inputUsername = ref(props.username);
const inputEmail = ref(props.email);
const inputPhone = ref(props.phone);
const inputActive = ref(props.is_active);
const inputAdmin = ref(props.is_admin);
const inputPassword = ref('');
const inputPassword2 = ref('');

onMounted(() => {
  $('[data-toggle="tooltip"]', root.value).tooltip();
});

onUpdated(() => {
  if (selectGroups.value) {
    if (!$(selectGroups.value).data("multiselect")) {
      nextTick(setup_multiselects);
    }
    if ($(selectGroups.value).data("multiselect")) {
      $(selectGroups.value).multiselect(props.waiting ? "disable" : "enable");
    }
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
  $(selectGroups.value).multiselect(multiselectOptions);
}

function teardown_multiselects() {
  $(selectGroups.value).multiselect("destroy");
}

function submit() {
  // data generates payload for POST /json/settings/users
  const data = {
    // Define parameters.
    new_username:  inputUsername.value.value,
    email: inputEmail.value.value,
    phone: inputPhone.value.value,
    password: inputPassword.value.value,
    password2: inputPassword2.value.value,
    groups: $("#selectedGroups").val(),
    is_active: Boolean(inputActive.value.checked),
    is_admin: Boolean(inputAdmin.value.checked),
  };
  console.log("SUBMIT DATA", data);
  // emit("submit", data);
}

const emit = defineEmits(["submit"]);
defineExpose({ setup_multiselects, teardown_multiselects });
</script>

<template>
  <form v-on:submit.prevent="submit" ref="root">
    <div class="modal-body p-3">
      <div class="row" v-if="$slots.default">
        <div class="col">
          <!-- Error slot -->
          <slot></slot>
        </div>
      </div>

      <div class="row">
        <div class="form-group col-sm-6">
          <label class="control-label">Username<input type="text" class="form-control" placeholder="Username" ref="inputUsername" :value="username"/></label>
        </div>
        <div class="form-group col-sm-6">
          <label class="control-label">Email<input type="email" class="form-control" placeholder="Email" ref="inputEmail" :value="email"/></label>
          <span class="form-text text-muted small"
            >Leave blank to prevent user from receiving notifications by email.</span
          >
        </div>
      </div>

      <div class="row">
        <div class="form-group col-sm-6">
          <label class="control-label">Password&#42;
            <input type="password" class="form-control" placeholder="Password" ref="inputPassword"/>
            <input type="password" class="form-control" placeholder="Confirm password" ref="inputPassword2"/>
          </label>
          <p class="form-text text-muted"><small>&#42;: leave this field blank to keep it unchanged.</small></p>
        </div>

        <div class="form-group col-sm-6" v-if="groups.length > 0">
          <label class="control-label" for="selectedGroups">
            Groups<br />
            <select :disabled="waiting" multiple id="selectedGroups" ref="selectGroups">
            <option
              v-for="group in groups"
              :key="group.name"
              :selected="group.selected ? 'selected' : null"
              :value="group.name"
              :title="group.description"
            >
              {{ group.name }}
            </option></select
          ></label><br />
          <div class="custom-control custom-switch">
            <br />
            <input type="checkbox" class="custom-control-input" id="switchActive" ref="inputActive" :checked="is_active"/>
            <label class="custom-control-label" for="switchActive">Active</label><br />
          </div>
          <div class="custom-control custom-switch">
            <br />
             <input type="checkbox" class="custom-control-input" id="switchAdmin" ref="inputAdmin" :checked="is_admin"/>
            <label class="custom-control-label" for="switchAdmin">Administrator</label><br />
          </div>
        </div>
      </div>

      <div class="row">
        <div class="form-group col-sm-6">
          <label class="control-label">Phone
            <input type="text" class="form-control" placeholder="Phone" ref="inputPhone" :value="phone" />
          </label>
          <span class="form-text text-muted small"
            >Leave blank to prevent user from receiving notifications by SMS.</span
          >
        </div>
      </div>

      <div class="modal-footer">
        <button type="button" class="btn btn-outline-secondary" data-dismiss="modal">Cancel</button>
        <button type="submit" class="btn btn-success">Save</button>
      </div>
    </div>
  </form>
</template>
