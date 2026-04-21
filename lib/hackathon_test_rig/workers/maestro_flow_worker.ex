defmodule HackathonTestRig.Workers.MaestroFlowWorker do
  @moduledoc """
  Runs a Maestro flow via the `maestro-runner` CLI.

  Args:
    * `"maestro_flow"` - the flow YAML contents (string)
    * `"maestro_arguments"` - a `%{string => string}` map of env vars
      passed to maestro via `-e KEY=VALUE`

  The flow YAML is materialised to a temp file `flow-<job_id>.yaml` for the
  duration of the run and removed afterwards. Combined stdout/stderr is
  written to `results-<job_id>.txt` in the configured results directory
  (defaults to `results/` at the project root).
  """

  use Oban.Worker, queue: :default

  @impl Oban.Worker
  def perform(%Oban.Job{id: job_id, args: args}) do
    %{"maestro_flow" => flow_yaml, "maestro_arguments" => maestro_arguments} = args

    flow_path = Path.join(System.tmp_dir!(), "flow-#{job_id}.yaml")
    results_path = Path.join(results_dir(), "results-#{job_id}.txt")

    File.mkdir_p!(Path.dirname(results_path))
    File.write!(flow_path, flow_yaml)

    try do
      env_args =
        Enum.flat_map(maestro_arguments, fn {k, v} -> ["-e", "#{String.upcase(k)}=#{v}"] end)

      {output, exit_code} =
        System.cmd("maestro-runner", ["test"] ++ env_args ++ [flow_path],
          stderr_to_stdout: true
        )

      File.write!(results_path, output)

      case exit_code do
        0 -> :ok
        code -> {:error, "maestro-runner exited with status #{code}"}
      end
    after
      File.rm(flow_path)
    end
  end

  defp results_dir do
    Application.get_env(
      :hackathon_test_rig,
      :maestro_results_dir,
      Path.join(File.cwd!(), "results")
    )
  end
end
