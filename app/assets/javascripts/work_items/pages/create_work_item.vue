<script>
import { visitUrl, getParameterByName, updateHistory, removeParams } from '~/lib/utils/url_utility';
import CreateWorkItem from '../components/create_work_item.vue';
import CreateWorkItemCancelConfirmationModal from '../components/create_work_item_cancel_confirmation_modal.vue';
import {
  ROUTES,
  RELATED_ITEM_ID_URL_QUERY_PARAM,
  BASE_ALLOWED_CREATE_TYPES,
  WORK_ITEM_TYPE_ENUM_ISSUE,
  WORK_ITEM_TYPE_VALUE_MAP,
  WORK_ITEM_TYPE_ENUM_INCIDENT,
} from '../constants';
import workItemRelatedItemQuery from '../graphql/work_item_related_item.query.graphql';

export default {
  name: 'CreateWorkItemPage',
  components: {
    CreateWorkItem,
    CreateWorkItemCancelConfirmationModal,
  },
  inject: ['isGroup'],
  props: {
    workItemTypeName: {
      type: String,
      required: false,
      default: null,
    },
  },
  data() {
    return {
      relatedItem: null,
      relatedItemId: getParameterByName(RELATED_ITEM_ID_URL_QUERY_PARAM),
      isCancelConfirmationModalVisible: false,
      shouldDiscardDraft: false,
      workItemType: this.workItemTypeName,
    };
  },
  apollo: {
    relatedItem: {
      query: workItemRelatedItemQuery,
      variables() {
        return {
          id: this.relatedItemId,
        };
      },
      skip() {
        return !this.relatedItemId;
      },
      update({ workItem }) {
        return {
          id: this.relatedItemId,
          reference: workItem.reference,
          type: workItem.workItemType.name,
          webUrl: workItem.webUrl,
        };
      },
      error() {
        // if we cannot find an item with the given id, ignore it and remove it from the url.
        updateHistory({ url: removeParams([RELATED_ITEM_ID_URL_QUERY_PARAM]), replace: true });
      },
    },
  },
  computed: {
    isIssue() {
      return this.workItemTypeName === WORK_ITEM_TYPE_ENUM_ISSUE;
    },
    isIncident() {
      return this.workItemTypeName === WORK_ITEM_TYPE_ENUM_INCIDENT;
    },
    allowedWorkItemTypes() {
      if (this.isIssue || this.isIncident) {
        return BASE_ALLOWED_CREATE_TYPES;
      }

      return [];
    },
  },
  methods: {
    updateWorkItemType(type) {
      this.workItemType = type;
    },
    workItemCreated({ workItem, numberOfDiscussionsResolved }) {
      if (
        this.$router &&
        WORK_ITEM_TYPE_VALUE_MAP[this.workItemType] !== WORK_ITEM_TYPE_ENUM_INCIDENT
      ) {
        const routerPushObject = {
          name: ROUTES.workItem,
          params: { iid: workItem.iid },
        };
        if (numberOfDiscussionsResolved) {
          routerPushObject.query = { resolves_discussion: numberOfDiscussionsResolved };
        }
        this.$router.push(routerPushObject);
      } else {
        visitUrl(workItem.webUrl);
      }
    },
    handleCancelClick() {
      const listPath =
        this.$router.history.base + this.$router.history.current.fullPath.replace('/new', '');
      const isWorkItemRoute = this.$route.params?.type === 'work_items';
      const isGroupWorkItemRoute = isWorkItemRoute && this.$router.history.base.includes('groups');

      /*
        If the route is epics, issues or work items on the group level
        (because work items on the project level is not yet available)
        we redirect to the list page when the user clicks on cancel,
        otherwise we go back to the previous page.
      */

      if (Boolean(listPath) && (!isWorkItemRoute || isGroupWorkItemRoute)) {
        visitUrl(listPath);
      } else {
        this.$router.go(-1);
      }
    },
    hideConfirmationModal() {
      this.isCancelConfirmationModalVisible = false;
    },
    showConfirmationModal() {
      this.isCancelConfirmationModalVisible = true;
    },
    handleConfirmCancellation() {
      this.showConfirmationModal();
    },
    handleContinueEditing() {
      this.shouldDiscardDraft = false;
      this.hideConfirmationModal();
    },
    handleDiscardDraft() {
      this.hideConfirmationModal();
      this.handleCancelClick();
      // trigger discard draft function on create work item component
      this.shouldDiscardDraft = true;
    },
  },
};
</script>

<template>
  <div>
    <create-work-item
      :work-item-type-name="workItemTypeName"
      :is-group="isGroup"
      :related-item="relatedItem"
      :should-discard-draft="shouldDiscardDraft"
      :always-show-work-item-type-select="isIncident || isIssue"
      :allowed-work-item-types="allowedWorkItemTypes"
      @updateType="updateWorkItemType($event)"
      @confirmCancel="handleConfirmCancellation"
      @discardDraft="handleDiscardDraft('createPage')"
      @workItemCreated="workItemCreated"
    />
    <create-work-item-cancel-confirmation-modal
      v-if="workItemType"
      :is-visible="isCancelConfirmationModalVisible"
      :work-item-type-name="workItemType"
      @continueEditing="handleContinueEditing"
      @discardDraft="handleDiscardDraft('confirmModal')"
    />
  </div>
</template>
