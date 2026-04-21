defmodule HackathonTestRig.Inventory do
  @moduledoc """
  The Inventory context.
  """

  import Ecto.Query, warn: false
  alias HackathonTestRig.Repo

  alias HackathonTestRig.Inventory.TestRig

  @phone_counts_topic "inventory:phone_counts"
  @test_rigs_topic "inventory:test_rigs"

  @doc """
  Subscribe the current process to phone-count change notifications.
  The process will receive `{:phone_counts_changed, counts_by_rig_id}` messages,
  where `counts_by_rig_id` is a `%{test_rig_id => count}` map.
  """
  def subscribe_phone_counts do
    Phoenix.PubSub.subscribe(HackathonTestRig.PubSub, @phone_counts_topic)
  end

  @doc """
  Subscribe the current process to test-rig change notifications.
  The process will receive `:test_rigs_changed` messages on insert/update/delete.
  """
  def subscribe_test_rigs do
    Phoenix.PubSub.subscribe(HackathonTestRig.PubSub, @test_rigs_topic)
  end

  defp broadcast_phone_counts do
    Phoenix.PubSub.broadcast(
      HackathonTestRig.PubSub,
      @phone_counts_topic,
      {:phone_counts_changed, phone_counts_by_rig_id()}
    )
  end

  defp broadcast_test_rigs_changed do
    Phoenix.PubSub.broadcast(HackathonTestRig.PubSub, @test_rigs_topic, :test_rigs_changed)
  end

  @doc """
  Returns a `%{test_rig_id => phone_count}` map covering every test rig,
  including rigs with zero phones.
  """
  def phone_counts_by_rig_id do
    from(r in TestRig,
      left_join: p in assoc(r, :phones),
      group_by: r.id,
      select: {r.id, count(p.id)}
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
  Returns test rigs with their phone counts, as `{test_rig, phone_count}` tuples.
  """
  def list_test_rigs_with_phone_counts do
    from(r in TestRig,
      left_join: p in assoc(r, :phones),
      group_by: r.id,
      select: {r, count(p.id)},
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

  alias HackathonTestRig.Inventory.Phone

  @doc """
  Returns the list of phones.

  ## Examples

      iex> list_phones()
      [%Phone{}, ...]

  """
  def list_phones do
    Phone |> Repo.all() |> Repo.preload(:test_rig)
  end

  @doc """
  Returns the list of phones belonging to the given test rig id.
  """
  def list_phones_for_test_rig(test_rig_id) do
    from(p in Phone, where: p.test_rig_id == ^test_rig_id, order_by: [asc: p.name])
    |> Repo.all()
  end

  @doc """
  Gets a single phone.

  Raises `Ecto.NoResultsError` if the Phone does not exist.

  ## Examples

      iex> get_phone!(123)
      %Phone{}

      iex> get_phone!(456)
      ** (Ecto.NoResultsError)

  """
  def get_phone!(id), do: Phone |> Repo.get!(id) |> Repo.preload(:test_rig)

  @doc """
  Creates a phone.

  ## Examples

      iex> create_phone(%{field: value})
      {:ok, %Phone{}}

      iex> create_phone(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_phone(attrs) do
    result =
      %Phone{}
      |> Phone.changeset(attrs)
      |> Repo.insert()

    with {:ok, _phone} <- result, do: broadcast_phone_counts()
    result
  end

  @doc """
  Updates a phone.

  ## Examples

      iex> update_phone(phone, %{field: new_value})
      {:ok, %Phone{}}

      iex> update_phone(phone, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_phone(%Phone{} = phone, attrs) do
    result =
      phone
      |> Phone.changeset(attrs)
      |> Repo.update()

    with {:ok, updated} <- result,
         true <- updated.test_rig_id != phone.test_rig_id do
      broadcast_phone_counts()
    end

    result
  end

  @doc """
  Deletes a phone.

  ## Examples

      iex> delete_phone(phone)
      {:ok, %Phone{}}

      iex> delete_phone(phone)
      {:error, %Ecto.Changeset{}}

  """
  def delete_phone(%Phone{} = phone) do
    result = Repo.delete(phone)
    with {:ok, _phone} <- result, do: broadcast_phone_counts()
    result
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking phone changes.

  ## Examples

      iex> change_phone(phone)
      %Ecto.Changeset{data: %Phone{}}

  """
  def change_phone(%Phone{} = phone, attrs \\ %{}) do
    Phone.changeset(phone, attrs)
  end

  @doc """
  Returns a `[{queue_name, concurrency}]` keyword list with one queue per phone.

  Used to build the Oban queue list at application boot. Oban Pro supports
  adding queues dynamically at runtime; until we adopt that, the queue list
  is fixed to the phones present when the app starts.
  """
  def oban_queues do
    from(p in Phone, select: p.name, order_by: [asc: p.name])
    |> Repo.all()
    |> Enum.map(fn name -> {Phone.queue_name(name), 1} end)
  end
end
