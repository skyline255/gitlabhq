module Gitlab
  module Kubernetes
    module Helm
      class KubectlCommand
        include BaseCommand

        attr_reader :name, :scripts, :files

        def initialize(name:, scripts:, files: {})
          @name = name
          @files = files
          @rbac = true
          @scripts = scripts
        end

        def service_account_resource
          return unless rbac?

          Gitlab::Kubernetes::ServiceAccount.new(service_account_name, namespace).generate
        end

        def cluster_role_binding_resource
          return unless rbac?

          subjects = [{ kind: 'ServiceAccount', name: service_account_name, namespace: namespace }]

          Gitlab::Kubernetes::ClusterRoleBinding.new(
            cluster_role_binding_name,
            cluster_role_name,
            subjects
          ).generate
        end

        def base_script
          <<~HEREDOC
            set -eo pipefail
            ALPINE_VERSION=$(cat /etc/alpine-release | cut -d '.' -f 1,2)
            echo http://mirror.clarkson.edu/alpine/v$ALPINE_VERSION/main >> /etc/apk/repositories
            echo http://mirror1.hs-esslingen.de/pub/Mirrors/alpine/v$ALPINE_VERSION/main >> /etc/apk/repositories
            apk add -U wget ca-certificates openssl >/dev/null

            wget -O /etc/apk/keys/sgerrand.rsa.pub https://alpine-pkgs.sgerrand.com/sgerrand.rsa.pub
            wget https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.28-r0/glibc-2.28-r0.apk
            apk add glibc-2.28-r0.apk
            rm glibc-2.28-r0.apk

            wget https://storage.googleapis.com/kubernetes-release/release/v1.11.0/bin/linux/amd64/kubectl
            chmod +x kubectl
            mv kubectl /usr/bin/
          HEREDOC
        end

        def generate_script
          ([base_script] + scripts).join("\n")
        end

        def rbac?
          @rbac
        end

        def cluster_role_binding_name
          Gitlab::Kubernetes::Helm::CLUSTER_ROLE_BINDING
        end

        def cluster_role_name
          Gitlab::Kubernetes::Helm::CLUSTER_ROLE
        end
      end
    end
  end
end
