Feature: oc related features
  # @author pruan@redhat.com
  # @case_id 497509
  Scenario: Check OpenShift Concepts and Types via oc types
    When I run the :help client command
    Then the output should contain:
      | types |
      | An introduction to concepts and types |
    When I run the :types client command with:
      | help | true |
    Then the output should contain:
      | Concepts: |
      | * Containers: |
      | A definition of how to run one or more processes inside of a portable Linux |
      | environment. Containers are started from an Image and are usually isolated  |
      | * Image:                                                                    |
      | * Pods [pod]:                                                               |
      | * Labels:                                                                   |
      | * Volumes:                                                                  |
      | * Nodes [node]:                                                           |
      | * Routes [route]:                                                   |
      | * Replication Controllers [rc]:                                     |
      | * Deployment Configuration [dc]:                                    |
      | * Build Configuration [bc]:                                         |
      | * Image Streams and Image Stream Tags [is,istag]:                   |
      | * Projects [project]:                                               |
      | Usage:                                                              |
      |  oc types [options]                                                 |

  # @author pruan@redhat.com
  # @case_id 497521
  Scenario: Check the help page of oc edit
    When I run the :edit client command with:
      | help | true |
    Then the output should contain:
      | Edit a resource from the default editor |
      | The edit command allows you to directly edit any API resource you can retrieve via the |
      | command line tools. It will open the editor defined by your OC_EDITOR, GIT_EDITOR,     |
      | or EDITOR environment variables, or fall back to 'vi' for Linux or 'notepad' for Windows. |
      | Usage:                                                                                    |
      | oc edit (RESOURCE/NAME \| -f FILENAME) [options] |

  # @author cryan@redhat.com
  # @case_id 497907
  Scenario: Check --list/-L option for new-app
    When I run the :new_app client command with:
      |help||
    Then the output should contain:
      | oc new-app --list |
      | -L, --list=false  |

  # @author cryan@redhat.com
  # @case_id 470720
  Scenario: Check help info for oc config
    When I run the :config client command with:
      | h ||
    Then the output should contain:
      | Manage the client config files |
      | oc config SUBCOMMAND [options] |
      | Examples |

  # @author pruan@redhat.com
  # @case_id 487931
  Scenario: Check the help page for oc export
    When I run the :export client command with:
      | help | true |
    Then the output should contain:
      | Export resources so they can be used elsewhere |
      | The export command makes it easy to take existing objects and convert them to configuration files |
      | for backups or for creating elsewhere in the cluster. |
      | oc export RESOURCE/NAME ... [options] [options] |

  # @author pruan@redhat.com
  # @case_id 483189
  Scenario: Check the help page for oc deploy
    When I run the :deploy client command with:
      | help              | true   |
      | deployment_config | :false |
    Then the output should contain:
      | View, start, cancel, or retry a deployment |
      | This command allows you to control a deployment config. |
      | oc deploy DEPLOYMENTCONFIG [--latest\|--retry\|--cancel\|--enable-triggers] [options] |
      | --cancel=false: Cancel the in-progress deployment.      |
      | --enable-triggers=false: Enables all image triggers for the deployment config. |
      | --latest=false: Start a new deployment now.                                    |
      | --retry=false: Retry the latest failed deployment.                             |

  # @author pruan@redhat.com
  # @case_id 492274
  Scenario: Check help doc of command 'oc tag'
    When I run the :tag client command with:
      | source | :false |
      | dest   | :false |
      | h      | true   |
    Then the output should contain:
      | Tag existing images into image streams                                         |
      | The tag command allows you to take an existing tag or image from an image      |
      | stream, or a Docker image pull spec, and set it as the most recent image for a |
      | tag in 1 or more other image streams. It is similar to the 'docker tag'        |
      | command, but it operates on image streams instead.                             |
      | oc tag [--source=SOURCETYPE] SOURCE DEST [DEST ...] [options]                  |
    When I run the :tag client command with:
      | source | :false |
      | dest   | :false |
      | help   | true   |
    Then the output should contain:
      | Tag existing images into image streams                                         |
      | The tag command allows you to take an existing tag or image from an image      |
      | stream, or a Docker image pull spec, and set it as the most recent image for a |
      | tag in 1 or more other image streams. It is similar to the 'docker tag'        |
      | command, but it operates on image streams instead.                             |
      | oc tag [--source=SOURCETYPE] SOURCE DEST [DEST ...] [options]                  |

  # @author wsun@redhat.com
  # @case_id 499948
  Scenario: Check the help page for oc annotate
    When I run the :help client command
    Then the output should contain:
      | annotate |
      | Update the annotations on a resource |
    When I run the :annotate client command with:
      | help | true |
    Then the output should contain:
      | Update the annotations on one or more resources |
      | oc annotate [--overwrite] (-f FILENAME \| TYPE NAME) KEY_1=VAL_1 ... KEY_N=VAL_N [--resource-version=version] [options] |
      | --all=false: select all resources in the namespace of the specified resource types |
      | -f, --filename=[]: Filename, directory, or URL to a file identifying the resource to update the annotation |
      | --overwrite=false: If true, allow annotations to be overwritten, otherwise reject annotation updates that overwrite existing annotations. |
      | --resource-version='': If non-empty, the annotation update will only succeed if this is the current resource-version for the object. Only valid when specifying a single resource. |

  # @author yanpzhan@redhat.com
  # @case_id 499893
  Scenario: Check help info for oc run
    When I run the :help client command
    Then the output should contain:
      | run |
      | Run a particular image on the cluster |
    When I run the :run client command with:
      | help | true   |
      | name | :false |
    Then the output should contain:
      |Create and run a particular image, possibly replicated                                                 |
      |oc run NAME --image=image [--env="key=value"] [--port=port] [--replicas=replicas] [--dry-run=bool] [--overrides=inline-json] |
      |--attach=false: If true, wait for the Pod to start running, and then attach to the Pod as if 'kubectl attach ...' were called.  Default false, unless '-i/--interactive' is set, in which case the default is true. |
      |--dry-run=false: If true, only print the object that would be sent, without sending it.                |
      |--generator='': The name of the API generator to use.  Default is 'run/v1' if --restart=Always, otherwise the default is 'run-pod/v1'.|
      |--hostport=-1: The host port mapping for the container port. To demonstrate a single-machine container.|
      |--image='': The image for the container to run.|
      |-l, --labels='': Labels to apply to the pod(s).|
      |--no-headers=false: When using the default output, don't print headers.      |
      |--output-version='': Output the formatted object with the given version (default api-version).|
      |--overrides='': An inline JSON override for the generated object. If this is non-empty, it is used to override the generated object. Requires that the object supply a valid apiVersion field.|
      |--port=-1: The port that this container exposes.|
      |-r, --replicas=1: Number of replicas to create for this container. Default is 1.|
      |--restart='Always': The restart policy for this Pod.  Legal values [Always, OnFailure, Never].|
      |-i, --stdin=false: Keep stdin open on the container(s) in the pod, even if nothing is attached.|
      |-t, --template='': Template string or path to template file to use when -o=go-template, -o=go-template-file. |
      |--tty=false: Allocated a TTY for each container in the pod.|

  # @author xxia@redhat.com
  # @case_id 510553
  Scenario: Use oc explain to see detailed documentation of resources
    When I run the :explain client command with:
      | help | true  |
    Then the output should contain:
      | Documentation of resources |
      | Possible resource types    |
    When I run the :explain client command with:
      | resource  | po |
    Then the step should succeed
    And the output should contain:
      | DESCRIPTION |
      | Pod is a collection of containers |
      | FIELDS      |
      | apiVersion  |
    When I run the :explain client command with:
      | resource  | pods.spec.containers |
    Then the step should succeed
    And the output should contain:
      | RESOURCE: containers |
      | DESCRIPTION |
      | List of containers belonging to the pod |
      | FIELDS      |
      | securityContext  |
    When I run the :explain client command with:
      | resource  | svc |
    Then the step should succeed
    When I run the :explain client command with:
      | resource  | pvc |
    Then the step should succeed
    When I run the :explain client command with:
      | resource  | rc.spec.selector |
    Then the step should succeed

    When I run the :explain client command with:
      | resource  | dc |
    Then the step should succeed
    When I run the :explain client command with:
      | resource  | no-this |
    Then the step should fail
    When I run the :explain client command with:
      | resource  | rc,no |
    Then the step should fail
    And the output should contain:
      | rc,no |

  # @author pruan@redhat.com
  # @case_id 474043
  Scenario: Check cli and subcommands help docs
    When I run the :help client command
    Then the step should succeed
    And the output should contain:
      | Use "oc help <command>" for more information about a given command. |
      | Use "oc options" for a list of global command-line options (applies to all commands). |
    When I run the :options client command
    Then the step should succeed
    And the output should contain:
      | The following options can be passed to any command |
      | --api-version                                      |
      | --certificate-authority                            |
      | --client-certificate                               |
      | --client-key                                       |
      | --cluster                                          |
      | --config                                           |
      | --context                                          |
      | --insecure-skip-tls-verify                         |
      | --log-flush-frequency                              |
      | --loglevel                                         |
      | --match-server-version                             |
      | --namespace                                        |
      | --server                                           |
      | --token                                            |
      | --user                                             |
    # now check the subcommands
    When I run the :new_app client command with:
      | help |  |
    Then the step should succeed
    And the output should contain:
      | Create a new application by specifying source code, templates, and/or images |
    When I run the :start_build client command with:
      | help |  |
    Then the step should succeed
    And the output should contain:
      | Start a build |
    When I run the :cancel_build client command with:
      | build_name | :false |
      | help       |        |
    Then the step should succeed
    And the output should contain "Cancels a pending or running build"
    When I run the :rollback client command with:
      | deployment_name | :false |
      | help            |        |
    Then the step should succeed
    And the output should contain "Revert an application back to a previous deployment"
    When I run the :get client command with:
      | resource | :false |
      | help     |        |
    Then the step should succeed
    And the output should contain "Display one or many resources"
    When I run the :describe client command with:
      | resource | :false |
      | help     |        |
    Then the step should succeed
    And the output should contain "Show details of a specific resource"
    When I run the :create client command with:
      | help |  |
    Then the step should succeed
    And the output should contain "Create a resource by filename or stdin"
    When I run the :delete client command with:
      | help |  |
    Then the step should succeed
    And the output should contain "Delete a resource"
    When I run the :process client command with:
      | help |  |
    Then the step should succeed
    And the output should contain "Process template into a list of resources specified in filename or stdin"
    When I run the :replace client command with:
      | help |  |
    Then the step should succeed
    And the output should contain "Replace a resource by filename or stdin"
    When I run the :project client command with:
      | help |  |
    Then the step should succeed
    And the output should contain "Switch to another project and make it the default in your configuration"
    When I run the :logs client command with:
      | resource_name | :false |
      | help          |        |
    Then the step should succeed
    And the output should contain "Print the logs for a resource"
    When I run the :proxy client command with:
      | help |  |
    Then the step should succeed
    And the output should contain "Run a proxy to the Kubernetes API server"
    When I run the :build_logs client command with:
      | build_name | :false |
      | help       |        |
    Then the step should succeed
    And the output should contain:
      | DEPRECATED: This command has been moved to "oc logs"  |