# EX_Tii item icons

Rendered with Blender (bpy 5.2) from free CC0 Poly Haven models/textures plus procedural models.
- `studio.py` camera/light/transparent background, `post.py` crop to 256 px
- recipes: `r_job.py r_mech.py r_med.py r_food.py r_misc.py r_tools.py` (one function per item)
- `python3 render.py r_med gauze` renders one item; `QUICK=1` for a fast preview
- `install_map.py` maps each item to its file on the server (ox_inventory/web/images, or the job/mechanic html/items folders)
- weapon/ammo/attachment pictures are the original GTA renders and were not touched
