import { GlModal, GlSprintf, GlButton } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import { createAlert } from '~/alert';
import DeletePodModal from '~/environments/environment_details/components/kubernetes/delete_pod_modal.vue';
import waitForPromises from 'helpers/wait_for_promises';
import { stubComponent } from 'helpers/stub_component';
import { mockPodsTableItems } from 'jest/kubernetes_dashboard/graphql/mock_data';
import { mockKasTunnelUrl } from '../../../mock_data';

Vue.use(VueApollo);
jest.mock('~/alert');

describe('~/environments/environment_details/components/kubernetes/delete_pod_modal.vue', () => {
  let wrapper;

  const configuration = {
    basePath: mockKasTunnelUrl.replace(/\/$/, ''),
    baseOptions: {
      headers: { 'GitLab-Agent-Id': '1' },
      withCredentials: true,
    },
  };

  const defaultProps = {
    configuration,
    pod: mockPodsTableItems[0],
  };

  let deleteKubernetesPodMutationMock;
  const showToast = jest.fn();

  const modalStub = `
    <div>
      <slot></slot>
      <slot name="modal-footer"></slot>
    </div>
  `;

  const createApolloProvider = () => {
    const mockResolvers = {
      Mutation: {
        deleteKubernetesPod: deleteKubernetesPodMutationMock,
      },
    };

    return createMockApollo([], mockResolvers);
  };

  function createComponent(props = defaultProps) {
    const apolloProvider = createApolloProvider();
    wrapper = shallowMountExtended(DeletePodModal, {
      propsData: {
        ...props,
      },
      apolloProvider,
      stubs: {
        GlModal: stubComponent(GlModal, { template: modalStub }),
        GlSprintf,
      },
      mocks: {
        $toast: {
          show: showToast,
        },
      },
    });
  }

  const findModal = () => wrapper.findComponent(GlModal);
  const findDeletePodButton = () => wrapper.findByTestId('delete-pod-button');

  beforeEach(() => {
    deleteKubernetesPodMutationMock = jest.fn().mockResolvedValue({ errors: [] });
  });

  describe('when pod is not empty', () => {
    it('renders the modal', () => {
      createComponent();
      expect(findModal().exists()).toBe(true);
    });

    it('renders modal text with the pod name', () => {
      createComponent();
      expect(findModal().text()).toContain(
        'Are you sure you want to delete pod-1? This action cannot be undone.',
      );
    });

    it('renders modal footer with action buttons', () => {
      createComponent();

      expect(findModal().findAllComponents(GlButton).at(0).text()).toBe('Cancel');
      expect(findModal().findAllComponents(GlButton).at(1).text()).toBe('Delete pod');
    });

    describe('delete pod successfully', () => {
      beforeEach(async () => {
        createComponent();
        findDeletePodButton().vm.$emit('click');
        await nextTick();
      });

      it('calls the mutation when primary button is clicked', () => {
        expect(deleteKubernetesPodMutationMock).toHaveBeenCalledWith(
          {},
          {
            configuration,
            namespace: 'default',
            podName: 'pod-1',
          },
          expect.anything(),
          expect.anything(),
        );
      });

      it('updates loading state of the primary button', async () => {
        expect(findDeletePodButton().props('loading')).toBe(true);
        await waitForPromises();

        expect(findDeletePodButton().props('loading')).toBe(false);
      });

      it('shows success toast if the pod was deleted', async () => {
        await waitForPromises();

        expect(showToast).toHaveBeenCalledWith('Pod deleted successfully');
      });
    });

    describe('error on pod deletion', () => {
      const errorMessage = 'Error deleting pod';
      beforeEach(async () => {
        deleteKubernetesPodMutationMock = jest.fn().mockResolvedValue({ errors: [errorMessage] });
        createComponent();
        findDeletePodButton().vm.$emit('click');
        await waitForPromises();
      });

      it('shows error alert if the pod was not deleted', () => {
        expect(createAlert).toHaveBeenCalledWith({
          message: `Error: ${errorMessage}`,
          variant: 'danger',
        });
      });
    });
  });
});
