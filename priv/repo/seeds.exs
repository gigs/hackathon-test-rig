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
alias HackathonTestRig.Inventory.{Phone, TestRig}
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

phone_templates = [
  %{type: :ios, device_model: "iPhone 15 Pro", os_version: "17.5", suffix: "ios-1"},
  %{type: :ios, device_model: "iPhone 14", os_version: "16.7", suffix: "ios-2"},
  %{type: :android, device_model: "Pixel 8", os_version: "14", suffix: "android-1"},
  %{type: :android, device_model: "Samsung Galaxy S24", os_version: "14", suffix: "android-2"}
]

for {rig_name, rig} <- rigs, template <- phone_templates do
  phone_name = "#{rig_name}-#{template.suffix}"

  case Repo.get_by(Phone, name: phone_name) do
    nil ->
      {:ok, _} =
        Inventory.create_phone(%{
          name: phone_name,
          type: template.type,
          device_model: template.device_model,
          os_version: template.os_version,
          test_rig_id: rig.id
        })

    _existing ->
      :ok
  end
end
