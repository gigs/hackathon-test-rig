defmodule HackathonTestRig.Inventory do
  @moduledoc """
  The Inventory context.
  """

  import Ecto.Query, warn: false
  alias HackathonTestRig.Repo

  alias HackathonTestRig.Inventory.TestRig

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
    %TestRig{}
    |> TestRig.changeset(attrs)
    |> Repo.insert()
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
    test_rig
    |> TestRig.changeset(attrs)
    |> Repo.update()
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
    Repo.delete(test_rig)
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
    %Phone{}
    |> Phone.changeset(attrs)
    |> Repo.insert()
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
    phone
    |> Phone.changeset(attrs)
    |> Repo.update()
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
    Repo.delete(phone)
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
end
