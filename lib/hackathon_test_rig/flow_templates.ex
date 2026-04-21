defmodule HackathonTestRig.FlowTemplates do
  @moduledoc """
  Preconfigured Maestro flow templates loaded from the `flows/` directory.

  Template names are the YAML filenames without their extension. The special
  name `"custom"` is reserved for free-form user-authored flows and does not
  correspond to a file on disk.
  """

  @custom "custom"
  @preferred_order ["android-esim-install"]

  @doc """
  Returns the name used for custom (user-authored) flows.
  """
  def custom_name, do: @custom

  @doc """
  Lists available template names ordered for display.

  Preferred templates come first (in `@preferred_order`), followed by the rest
  alphabetically, with `"custom"` appended as the fallback.
  """
  def list do
    preferred = Enum.filter(@preferred_order, &File.exists?(path_for(&1)))

    others =
      flows_dir()
      |> File.ls()
      |> case do
        {:ok, files} -> files
        {:error, _} -> []
      end
      |> Enum.filter(&String.ends_with?(&1, ".yaml"))
      |> Enum.map(&Path.rootname(&1, ".yaml"))
      |> Enum.reject(&(&1 in preferred))
      |> Enum.sort()

    preferred ++ others ++ [@custom]
  end

  @doc """
  Returns `{:ok, yaml}` for a known template, or `:error` if the name is not
  resolvable (including `"custom"`, which has no file).
  """
  def load(name) when is_binary(name) and name != @custom do
    path = path_for(name)

    if File.exists?(path) do
      {:ok, File.read!(path)}
    else
      :error
    end
  end

  def load(_), do: :error

  defp path_for(name), do: Path.join(flows_dir(), name <> ".yaml")

  defp flows_dir do
    Application.get_env(
      :hackathon_test_rig,
      :flow_templates_dir,
      Path.join(File.cwd!(), "flows")
    )
  end
end
