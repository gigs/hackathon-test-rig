# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     HackathonTestRig.Repo.insert!(%HackathonTestRig.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias HackathonTestRig.Inventory
alias HackathonTestRig.Inventory.{Device, TestRig}
alias HackathonTestRig.Repo

test_rigs = [
  %{name: "london", hostname: "london.rigs.local", location: "London, UK"},
  %{name: "berlin", hostname: "berlin.rigs.local", location: "Berlin, DE"}
]

upsert_test_rig = fn attrs ->
  case Repo.get_by(TestRig, name: attrs.name) do
    nil ->
      {:ok, test_rig} = Inventory.create_test_rig(attrs)
      test_rig

    existing ->
      existing
  end
end

rigs = Map.new(test_rigs, fn attrs -> {attrs.name, upsert_test_rig.(attrs)} end)

device_templates = [
  %{type: :smartphone, brand: "Apple", suffix: "ios-1"},
  %{type: :smartphone, brand: "Apple", suffix: "ios-2"},
  %{type: :smartphone, brand: "Google", suffix: "android-1"},
  %{type: :smartphone, brand: "Samsung", suffix: "android-2"}
]

for {rig_name, rig} <- rigs, template <- device_templates do
  device_name = "#{rig_name}-#{template.suffix}"

  case Repo.get_by(Device, name: device_name) do
    nil ->
      {:ok, _} =
        Inventory.create_device(%{
          name: device_name,
          type: template.type,
          brand: template.brand,
          test_rig_id: rig.id
        })

    _existing ->
      :ok
  end
end
