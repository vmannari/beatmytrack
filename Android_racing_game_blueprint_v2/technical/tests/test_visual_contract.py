"""Documentation/framing contract checks, NOT game-engine acceptance tests."""
import json, struct, unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
class VisualContract(unittest.TestCase):
    def setUp(self):
        self.c=json.loads((ROOT/'ui/Camera_contract.json').read_text())
        self.m=json.loads((ROOT/'ui/assets/camera_calibration.json').read_text())
    def test_overhead_no_horizon(self):
        self.assertEqual(self.c['view'],'high_oblique_overhead_follow')
        self.assertTrue(self.c['no_horizon'])
    def test_requested_magnification(self):
        self.assertEqual(self.c['linear_magnification'],1.15)
        self.assertAlmostEqual(self.c['baseline_extent_multiplier'],1/1.15)
    def test_no_mesh_or_physics_resize(self):
        self.assertEqual(self.c['car_mesh_scale_multiplier'],1)
        self.assertEqual(self.c['collision_geometry_scale_multiplier'],1)
    def test_hud_not_zoomed(self): self.assertEqual(self.c['hud_scale_multiplier'],1)
    def test_crop_magnification(self):
        x0,y0,x1,y1=self.m['source_crop_px'];w,h=self.m['source_size_px']
        self.assertAlmostEqual(w/(x1-x0),1.15)
        self.assertAlmostEqual(h/(y1-y0),1.15)
    def test_source_and_target_dimensions(self):
        for rel in [self.m['source'],self.m['derived']]:
            content=(ROOT/'ui'/rel).read_bytes()
            self.assertEqual(content[:8],b'\x89PNG\r\n\x1a\n')
            self.assertEqual(list(struct.unpack('>II',content[16:24])),self.m['source_size_px'])
    def test_separate_menu_authority(self):
        doc=(ROOT/'ui/UI_Art_Direction.md').read_text()
        self.assertIn('explicitly rejected for gameplay',doc)
        self.assertIn('15% larger in linear on-screen size',doc)
    def test_reference_assets_exist(self):
        for name in ['gameplay_approved.png','menus_style_reference.png','menus_only.png','cel_shading_reference.png']:
            self.assertTrue((ROOT/'ui/references'/name).is_file())
if __name__=='__main__': unittest.main()
