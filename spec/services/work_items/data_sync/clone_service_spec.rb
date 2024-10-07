# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::DataSync::CloneService, feature_category: :team_planning do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:target_project) { create(:project, group: group) }
  let_it_be_with_reload(:issue_work_item) { create(:work_item, :opened, project: project) }
  let_it_be(:task_work_item) { create(:work_item, :task, project: project) }
  let_it_be(:source_project_member) { create(:user, reporter_of: project) }
  let_it_be(:target_project_member) { create(:user, reporter_of: target_project) }
  let_it_be(:projects_member) { create(:user, reporter_of: [project, target_project]) }

  let(:original_work_item) { issue_work_item }
  let(:target_namespace) { target_project.project_namespace.reload }

  let(:service) do
    described_class.new(
      work_item: original_work_item,
      target_namespace: target_namespace,
      current_user: current_user
    )
  end

  context 'when user does not have permissions' do
    context 'when user cannot read original work item' do
      let(:current_user) { target_project_member }

      it 'raises error' do
        expect { service.execute }.to raise_error(
          described_class::CloneError, 'Cannot clone work item due to insufficient permissions!'
        )
      end
    end

    context 'when user cannot create work items in target namespace' do
      let(:current_user) { source_project_member }

      it 'raises error' do
        expect { service.execute }.to raise_error(
          described_class::CloneError, 'Cannot clone work item due to insufficient permissions!'
        )
      end
    end
  end

  context 'when user has permission to clone work item' do
    let(:current_user) { projects_member }

    context 'when cloning project level work item to a group' do
      let(:target_namespace) { group }

      it 'raises error' do
        expect { service.execute }.to raise_error(
          described_class::CloneError, 'Cannot clone work item between Projects and Groups.'
        )
      end
    end

    context 'when cloning to a pending delete project' do
      before do
        target_namespace.project.update!(pending_delete: true)
      end

      after do
        target_namespace.project.update!(pending_delete: false)
      end

      it 'raises error' do
        expect { service.execute }.to raise_error(
          described_class::CloneError, 'Cannot clone work item to target namespace as it is pending deletion.'
        )
      end
    end

    context 'when cloning unsupported work item type' do
      let(:original_work_item) { task_work_item }

      it 'raises error' do
        expect { service.execute }.to raise_error(
          described_class::CloneError, 'Cannot clone work items of \'Task\' type.'
        )
      end
    end

    context 'when cloning work item raises an error' do
      let(:error_message) { 'Something went wrong' }

      before do
        allow_next_instance_of(::WorkItems::DataSync::BaseCreateService) do |create_service|
          allow(create_service).to receive(:execute).and_return(ServiceResponse.error(message: error_message))
        end
      end

      it 'raises error' do
        expect { service.execute }.to raise_error(described_class::CloneError, error_message)
      end
    end

    context 'when cloning work item with success' do
      let(:expected_original_work_item_state) { Issue.available_states[:opened] }
      let!(:original_work_item_attrs) do
        {
          title: original_work_item.title,
          description: original_work_item.description,
          author: current_user,
          work_item_type: original_work_item.work_item_type,
          state_id: Issue.available_states[:opened],
          updated_by: current_user,
          last_edited_at: nil,
          last_edited_by: nil,
          closed_at: nil,
          closed_by: nil,
          duplicated_to_id: nil,
          moved_to_id: nil,
          promoted_to_epic_id: nil,
          external_key: nil,
          upvotes_count: 0,
          blocking_issues_count: 0,
          project: target_namespace.try(:project),
          namespace: target_namespace
        }
      end

      it_behaves_like 'cloneable and moveable work item'

      context 'with specific widgets' do
        let!(:assignees) { [source_project_member, target_project_member, projects_member] }

        it_behaves_like 'cloneable and moveable widget data'
      end
    end
  end
end
