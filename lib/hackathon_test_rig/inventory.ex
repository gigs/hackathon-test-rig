defmodule HackathonTestRig.Inventory do
  @moduledoc """
  The Inventory context.
  """

  import Ecto.Query, warn: false
  alias HackathonTestRig.Repo

  alias HackathonTestRig.Inventory.TestRig

  @device_counts_topic "inventory:device_counts"
  @test_rigs_topic "inventory:test_rigs"

  @doc """
  Subscribe the current process to device-count change notifications.
  The process will receive `{:device_counts_changed, counts_by_rig_id}` messages,
  where `counts_by_rig_id` is a `%{test_rig_id => count}` map.
  """
  def subscribe_device_counts do
    Phoenix.PubSub.subscribe(HackathonTestRig.PubSub, @device_counts_topic)
  end

  @doc """
  Subscribe the current process to test-rig change notifications.
  The process will receive `:test_rigs_changed` messages on insert/update/delete.
  """
  def subscribe_test_rigs do
    Phoenix.PubSub.subscribe(HackathonTestRig.PubSub, @test_rigs_topic)
  end

  defp broadcast_device_counts do
    Phoenix.PubSub.broadcast(
      HackathonTestRig.PubSub,
      @device_counts_topic,
      {:device_counts_changed, device_counts_by_rig_id()}
    )
  end

  defp broadcast_test_rigs_changed do
    Phoenix.PubSub.broadcast(HackathonTestRig.PubSub, @test_rigs_topic, :test_rigs_changed)
  end

  @doc """
  Returns a `%{test_rig_id => device_count}` map covering every test rig,
  including rigs with zero devices.
  """
  def device_counts_by_rig_id do
    from(r in TestRig,
      left_join: d in assoc(r, :devices),
      group_by: r.id,
      select: {r.id, count(d.id)}
    )
    |> Repo.all()
    |> Map.new()
  end

  @doc """
  Returns the list of test_rigs.

  ## Examples

      iex> list_test_rigs()
      [%TestRig{}, ...]

  """
  def list_test_rigs do
    Repo.all(TestRig)
  end

  @doc """
  Returns test rigs with their device counts, as `{test_rig, device_count}` tuples.
  """
  def list_test_rigs_with_device_counts do
    from(r in TestRig,
      left_join: d in assoc(r, :devices),
      group_by: r.id,
      select: {r, count(d.id)},
      order_by: [asc: r.name]
    )
    |> Repo.all()
  end

  @doc """
  Gets a single test_rig.

  Raises `Ecto.NoResultsError` if the Test rig does not exist.

  ## Examples

      iex> get_test_rig!(123)
      %TestRig{}

      iex> get_test_rig!(456)
      ** (Ecto.NoResultsError)

  """
  def get_test_rig!(id), do: Repo.get!(TestRig, id)

  @doc """
  Creates a test_rig.

  ## Examples

      iex> create_test_rig(%{field: value})
      {:ok, %TestRig{}}

      iex> create_test_rig(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_test_rig(attrs) do
    result =
      %TestRig{}
      |> TestRig.changeset(attrs)
      |> Repo.insert()

    with {:ok, _rig} <- result, do: broadcast_test_rigs_changed()
    result
  end

  @doc """
  Updates a test_rig.

  ## Examples

      iex> update_test_rig(test_rig, %{field: new_value})
      {:ok, %TestRig{}}

      iex> update_test_rig(test_rig, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_test_rig(%TestRig{} = test_rig, attrs) do
    result =
      test_rig
      |> TestRig.changeset(attrs)
      |> Repo.update()

    with {:ok, _rig} <- result, do: broadcast_test_rigs_changed()
    result
  end

  @doc """
  Deletes a test_rig.

  ## Examples

      iex> delete_test_rig(test_rig)
      {:ok, %TestRig{}}

      iex> delete_test_rig(test_rig)
      {:error, %Ecto.Changeset{}}

  """
  def delete_test_rig(%TestRig{} = test_rig) do
    result = Repo.delete(test_rig)
    with {:ok, _rig} <- result, do: broadcast_test_rigs_changed()
    result
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking test_rig changes.

  ## Examples

      iex> change_test_rig(test_rig)
      %Ecto.Changeset{data: %TestRig{}}

  """
  def change_test_rig(%TestRig{} = test_rig, attrs \\ %{}) do
    TestRig.changeset(test_rig, attrs)
  end

  alias HackathonTestRig.Inventory.Device

  @doc """
  Returns the list of devices.

  ## Examples

      iex> list_devices()
      [%Device{}, ...]

  """
  def list_devices do
    Device |> Repo.all() |> Repo.preload(:test_rig)
  end

  @doc """
  Returns the list of devices belonging to the given test rig id.
  """
  def list_devices_for_test_rig(test_rig_id) do
    from(d in Device, where: d.test_rig_id == ^test_rig_id, order_by: [asc: d.name])
    |> Repo.all()
  end

  @doc """
  Gets a single device.

  Raises `Ecto.NoResultsError` if the Device does not exist.

  ## Examples

      iex> get_device!(123)
      %Device{}

      iex> get_device!(456)
      ** (Ecto.NoResultsError)

  """
  def get_device!(id), do: Device |> Repo.get!(id) |> Repo.preload(:test_rig)

  @doc """
  Creates a device.

  ## Examples

      iex> create_device(%{field: value})
      {:ok, %Device{}}

      iex> create_device(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_device(attrs) do
    result =
      %Device{}
      |> Device.changeset(attrs)
      |> Repo.insert()

    with {:ok, _device} <- result, do: broadcast_device_counts()
    result
  end

  @doc """
  Updates a device.

  ## Examples

      iex> update_device(device, %{field: new_value})
      {:ok, %Device{}}

      iex> update_device(device, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_device(%Device{} = device, attrs) do
    result =
      device
      |> Device.changeset(attrs)
      |> Repo.update()

    with {:ok, updated} <- result,
         true <- updated.test_rig_id != device.test_rig_id do
      broadcast_device_counts()
    end

    result
  end

  @doc """
  Deletes a device.

  ## Examples

      iex> delete_device(device)
      {:ok, %Device{}}

      iex> delete_device(device)
      {:error, %Ecto.Changeset{}}

  """
  def delete_device(%Device{} = device) do
    result = Repo.delete(device)
    with {:ok, _device} <- result, do: broadcast_device_counts()
    result
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking device changes.

  ## Examples

      iex> change_device(device)
      %Ecto.Changeset{data: %Device{}}

  """
  def change_device(%Device{} = device, attrs \\ %{}) do
    Device.changeset(device, attrs)
  end

  @doc """
  Returns a `[{queue_name, concurrency}]` keyword list with one queue per device.

  Used to build the Oban queue list at application boot. Oban Pro supports
  adding queues dynamically at runtime; until we adopt that, the queue list
  is fixed to the devices present when the app starts.
  """
  def oban_queues do
    from(d in Device, select: d.name, order_by: [asc: d.name])
    |> Repo.all()
    |> Enum.map(fn name -> {Device.queue_name(name), 1} end)
  end
end
