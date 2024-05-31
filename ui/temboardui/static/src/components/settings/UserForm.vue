<script setup>
import { onMounted, reactive, ref, watch, watchEffect } from "vue";
import Multiselect from "vue-multiselect";
import "vue-multiselect/dist/vue-multiselect.min.css";

const props = defineProps([
  "waiting", // Whether parent is interacting with server.
  "username",
  "email",
  "phone",
  "groups",
  "is_active",
  "is_admin",
]);

const components = {
  Multiselect,
};

const root = ref(null);
const inputPassword = ref("");
const inputPassword2 = ref("");

const user = reactive({
  new_username: "",
  email: "",
  phone: "",
  password: "",
  password2: "",
  groups: [],
  objectgroups: [],
  is_active: false,
  is_admin: false,
});

onMounted(() => {
  $('[data-toggle="tooltip"]', root.value).tooltip();
});

watchEffect(() => {
  user.objectgroups = props.groups.filter((group) => group.selected).map((group) => group);
  user.new_username = props.username;
  user.email = props.email;
  user.phone = props.phone;
  user.password = inputPassword.value;
  user.password2 = inputPassword2.value;
  user.is_active = props.is_active || false;
  user.is_admin = props.is_admin || false;
});

watch(
  () => user.objectgroups,
  (groups) => {
    user.groups = groups.map((group) => group.name);
  },
);

function submit() {
  //console.log("SUBMIT DATA", user);
  emit("submit", user);
}

const emit = defineEmits(["submit"]);
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
          <label class="control-label"
            >Username<input type="text" class="form-control" placeholder="Username" v-model="user.new_username"
          /></label>
        </div>
        <div class="form-group col-sm-6">
          <label class="control-label"
            >Email<input type="email" class="form-control" placeholder="Email" v-model="user.email"
          /></label>
          <span class="form-text text-muted small"
            >Leave blank to prevent user from receiving notifications by email.</span
          >
        </div>
      </div>

      <div class="row">
        <div class="form-group col-sm-6">
          <label class="control-label"
            >Password&#42;
            <input type="password" class="form-control" placeholder="Password" v-model="user.password" />
            <input type="password" class="form-control" placeholder="Confirm password" v-model="user.password2" />
          </label>
          <p class="form-text text-muted"><small>&#42;: leave this field blank to keep it unchanged.</small></p>
        </div>

        <div class="form-group col-sm-6" v-if="props.groups.length > 0">
          <label class="control-label" :for="'selectedGroups' + props.username"> Groups<br /> </label><br />
          <multiselect
            v-model="user.objectgroups"
            :options="props.groups"
            :multiple="true"
            selectLabel=""
            deselectLabel=""
            label="name"
            trackBy="name"
          >
            <template #selection="{ values, isOpen }">
              <span class="multiselect__single" v-if="values.length == 1" v-show="!isOpen">{{ values[0].name }}</span>
              <span class="multiselect__single" v-else-if="values.length == props.groups.length" v-show="!isOpen"
                >All selected ({{ values.length }})</span
              >
              <span class="multiselect__single" v-else-if="values.length" v-show="!isOpen"
                >{{ values.length }} selected</span
              >
            </template>
          </multiselect>
          <input type="checkbox" class="custom-control-input" />
          <div class="custom-control custom-switch">
            <br />
            <input
              type="checkbox"
              class="custom-control-input"
              :id="'switchActive' + props.username"
              v-model="user.is_active"
            />
            <label class="custom-control-label" :for="'switchActive' + props.username">Active</label><br />
          </div>
          <div class="custom-control custom-switch">
            <br />
            <input
              type="checkbox"
              class="custom-control-input"
              :id="'switchAdmin' + props.username"
              v-model="user.is_admin"
            />
            <label class="custom-control-label" :for="'switchAdmin' + props.username">Administrator</label><br />
          </div>
        </div>
      </div>

      <div class="row">
        <div class="form-group col-sm-6">
          <label class="control-label"
            >Phone
            <input type="text" class="form-control" placeholder="Phone" v-model="user.phone" />
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
