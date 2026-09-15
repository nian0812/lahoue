# Runtime screenshot evidence — 2026-09-13

20 standalone 1920×1080 viewport captures, Godot 4.7.1 / NVIDIA GTX 1660 Ti. Controlled isolated fixtures exercise real runtime nodes and production textures. HUD is hidden for inspection; settings clipping is tested separately. These show both integrated art and remaining fallbacks, and are not a visual completion sign-off. The 0.65 overview is deliberately zoomed out beyond normal play.

- [starter_one_plot](captures/starter_one_plot.png) — zoom 1.0
- [restaurant_lv1](captures/restaurant_lv1.png) — zoom 1.4
- [restaurant_lv5_two_purchased](captures/restaurant_lv5_two_purchased.png) — zoom 1.4
- [food_pass_empty_lv5](captures/food_pass_empty_lv5.png) — zoom 1.4
- [food_pass_ready_lv5](captures/food_pass_ready_lv5.png) — zoom 1.4
- [food_pass_picked_up_lv5](captures/food_pass_picked_up_lv5.png) — zoom 1.4
- [creatures_motion_0](captures/creatures_motion_0.png) — zoom 1.3
- [creatures_motion_1](captures/creatures_motion_1.png) — zoom 1.3
- [farm_28_normal_scale](captures/farm_28_normal_scale.png) — zoom 1.0
- [world_overview_zoom_065](captures/world_overview_zoom_065.png) — zoom 0.65
- [world_west_normal_scale](captures/world_west_normal_scale.png) — zoom 1.0
- [world_east_normal_scale](captures/world_east_normal_scale.png) — zoom 1.0
- [depot_three_parked](captures/depot_three_parked.png) — zoom 1.6
- [truck_route_e](captures/truck_route_e.png) — zoom 1.6
- [truck_route_s](captures/truck_route_s.png) — zoom 1.6
- [truck_route_w](captures/truck_route_w.png) — zoom 1.6
- [truck_route_n](captures/truck_route_n.png) — zoom 1.6
- [helicopter_ready](captures/helicopter_ready.png) — zoom 1.6
- [helicopter_departing](captures/helicopter_departing.png) — zoom 1.6
- [helicopter_returning](captures/helicopter_returning.png) — zoom 1.6

`captures/runtime_texture_evidence.json` records texture paths and nodes visible in the scene tree; this includes nodes outside the current camera viewport. Truck/helicopter shots place actual presentation at controlled phase values; shipment timers are covered by regression tests.
