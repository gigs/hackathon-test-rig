defmodule HackathonTestRigWeb.HomeLive do
  use HackathonTestRigWeb, :live_view

  alias HackathonTestRig.Geocoding
  alias HackathonTestRig.Inventory

  @impl true
  def mount(_params, _session, socket) do
    markers =
      Inventory.list_test_rigs_with_phone_counts()
      |> Enum.map(fn {rig, phone_count} ->
        %{
          id: rig.id,
          name: rig.name,
          hostname: rig.hostname,
          location: rig.location,
          phone_count: phone_count,
          coordinates: Geocoding.coordinates(rig.location),
          path: ~p"/test_rigs/#{rig}"
        }
      end)

    {mapped, unmapped} = Enum.split_with(markers, & &1.coordinates)

    {:ok,
     socket
     |> assign(:page_title, "Test rig locations")
     |> assign(:markers, mapped)
     |> assign(:unmapped, unmapped)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.flash_group flash={@flash} />

    <div class="relative h-screen w-screen overflow-hidden">
      <div
        id="world-map"
        phx-hook=".WorldMap"
        phx-update="ignore"
        data-markers={Jason.encode!(Enum.map(@markers, &marker_payload/1))}
        class="absolute inset-0 z-0"
      >
      </div>

      <div class="pointer-events-none absolute inset-x-0 top-0 z-10 p-4 sm:p-6 lg:p-8">
        <div class="pointer-events-auto mx-auto flex max-w-5xl items-center justify-between gap-4 rounded-2xl bg-base-100/90 px-4 py-3 shadow-lg backdrop-blur">
          <div class="flex items-center gap-3">
            <img src={~p"/images/logo.svg"} width="28" alt="Phoenix" />
            <div>
              <div class="text-sm font-semibold">Test Rig Network</div>
              <div class="text-xs text-base-content/60">
                {length(@markers)} {ngettext("location", "locations", length(@markers))} on the map
              </div>
            </div>
          </div>
          <nav class="flex items-center gap-1">
            <.link
              navigate={~p"/test_rigs"}
              class="btn btn-ghost btn-sm"
            >
              Test rigs
            </.link>
            <.link navigate={~p"/phones"} class="btn btn-ghost btn-sm">Phones</.link>
            <Layouts.theme_toggle />
          </nav>
        </div>
      </div>

      <aside class="pointer-events-none absolute bottom-0 left-0 z-10 hidden p-4 sm:p-6 lg:p-8 md:block">
        <div class="pointer-events-auto w-80 rounded-2xl bg-base-100/90 p-4 shadow-lg backdrop-blur">
          <div class="mb-3 flex items-center justify-between">
            <h2 class="text-sm font-semibold">Rigs</h2>
            <span class="badge badge-sm">{length(@markers) + length(@unmapped)}</span>
          </div>
          <ul class="max-h-64 space-y-2 overflow-auto text-sm">
            <li :for={marker <- @markers}>
              <button
                type="button"
                phx-click={JS.dispatch("world-map:focus", detail: %{id: marker.id})}
                class="group flex w-full items-center justify-between rounded-lg px-2 py-1.5 text-left hover:bg-base-200"
              >
                <span class="flex items-center gap-2">
                  <span class="size-2 rounded-full bg-primary" />
                  <span class="font-medium">{marker.name}</span>
                  <span class="text-xs text-base-content/60">{marker.location}</span>
                </span>
                <span class="text-xs text-base-content/60">
                  {marker.phone_count} {ngettext("phone", "phones", marker.phone_count)}
                </span>
              </button>
            </li>
            <li :if={@unmapped != []} class="border-t border-base-300 pt-2 text-xs text-base-content/60">
              Unmapped locations:
              <span class="font-medium">
                {Enum.map_join(@unmapped, ", ", & &1.location)}
              </span>
            </li>
          </ul>
        </div>
      </aside>
    </div>

    <script :type={Phoenix.LiveView.ColocatedHook} name=".WorldMap">
      const LEAFLET_CSS = "https://unpkg.com/leaflet@1.9.4/dist/leaflet.css"
      const LEAFLET_JS = "https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"

      function ensureLeaflet() {
        if (window.__leafletLoader) return window.__leafletLoader
        window.__leafletLoader = new Promise((resolve, reject) => {
          if (!document.querySelector(`link[href="${LEAFLET_CSS}"]`)) {
            const link = document.createElement("link")
            link.rel = "stylesheet"
            link.href = LEAFLET_CSS
            document.head.appendChild(link)
          }
          if (window.L) return resolve(window.L)
          const script = document.createElement("script")
          script.src = LEAFLET_JS
          script.onload = () => resolve(window.L)
          script.onerror = reject
          document.head.appendChild(script)
        })
        return window.__leafletLoader
      }

      function tileLayerUrl() {
        const dark = document.documentElement.getAttribute("data-theme") === "dark"
        return dark
          ? "https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png"
          : "https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png"
      }

      export default {
        async mounted() {
          const L = await ensureLeaflet()
          const markers = JSON.parse(this.el.dataset.markers || "[]")

          const map = L.map(this.el, {
            worldCopyJump: true,
            minZoom: 2,
            zoomControl: true,
            attributionControl: true,
          }).setView([25, 10], 2)

          this.tileLayer = L.tileLayer(tileLayerUrl(), {
            attribution: '© <a href="https://www.openstreetmap.org/copyright">OSM</a> contributors, © <a href="https://carto.com/attributions">CARTO</a>',
            subdomains: "abcd",
            maxZoom: 19,
          }).addTo(map)

          this.map = map
          this.markers = new Map()

          const icon = L.divIcon({
            className: "rig-pin",
            html: '<span class="rig-pin__dot"></span><span class="rig-pin__ring"></span>',
            iconSize: [18, 18],
            iconAnchor: [9, 9],
          })

          markers.forEach(m => {
            const marker = L.marker([m.lat, m.lng], { icon, title: m.name }).addTo(map)
            const popup = `
              <div class="rig-popup">
                <div class="rig-popup__title">${m.name}</div>
                <div class="rig-popup__meta">${m.location}</div>
                <div class="rig-popup__meta"><code>${m.hostname}</code></div>
                <div class="rig-popup__meta">${m.phone_count} ${m.phone_count === 1 ? "phone" : "phones"}</div>
                <a class="rig-popup__link" href="${m.path}" data-phx-link="redirect" data-phx-link-state="push">Open rig →</a>
              </div>
            `
            marker.bindPopup(popup)
            this.markers.set(m.id, marker)
          })

          if (markers.length > 0) {
            const group = L.featureGroup(Array.from(this.markers.values()))
            map.fitBounds(group.getBounds().pad(0.4), { maxZoom: 5 })
          }

          this._onFocus = (e) => {
            const marker = this.markers.get(e.detail.id)
            if (!marker) return
            map.flyTo(marker.getLatLng(), 6, { duration: 0.8 })
            marker.openPopup()
          }
          window.addEventListener("world-map:focus", this._onFocus)

          this._onThemeChange = () => {
            this.tileLayer.setUrl(tileLayerUrl())
          }
          window.addEventListener("phx:set-theme", this._onThemeChange)

          setTimeout(() => map.invalidateSize(), 100)
        },

        destroyed() {
          window.removeEventListener("world-map:focus", this._onFocus)
          window.removeEventListener("phx:set-theme", this._onThemeChange)
          if (this.map) this.map.remove()
        },
      }
    </script>
    """
  end

  defp marker_payload(marker) do
    {lat, lng} = marker.coordinates

    %{
      id: marker.id,
      name: marker.name,
      hostname: marker.hostname,
      location: marker.location,
      phone_count: marker.phone_count,
      path: marker.path,
      lat: lat,
      lng: lng
    }
  end
end
