"""Regression tests for extraction and translator mistakes, using only the stdlib."""
import unittest

import localization as catalog


class CatalogTests(unittest.TestCase):
    def test_source_inventory_excludes_code_and_resources(self):
        for value in ("res://ui/car.png", "player_id", "hall_%d_%s", "%02d:%02d.%03d",
                      "shader_type spatial;", "<path fill='white'/>", r"void\s+fragment\s*\("):
            with self.subTest(value=value):
                self.assertFalse(catalog.display_text(value))
        for value in ("Language", "{count} coins", "LAP %02d / %s", "Sign in"):
            self.assertTrue(catalog.display_text(value))

    def test_po_round_trip_retains_unicode_newlines_and_plural(self):
        messages = {("", "Hello {name}\nAgain"): {"plural": "", "references": {"ui.gd:1"}},
                    ("", "{count} collision"): {"plural": "{count} collisions", "references": {"ui.gd:2"}}}
        entries = catalog.parse_po(catalog.render(messages, True))
        self.assertEqual(catalog.validate(entries, messages, "en"), [])
        self.assertEqual(entries[("", "Hello {name}\nAgain")]["msgstr"], "Hello {name}\nAgain")

    def test_missing_or_retyped_placeholders_are_rejected(self):
        messages = {("", "Buy {item} for {count} coins"): {"plural": "", "references": set()}}
        entries = catalog.parse_po(catalog.render(messages, True))
        entries[("", "Buy {item} for {count} coins")]["msgstr"] = "Buy {item}"
        self.assertTrue(any("placeholders" in error for error in catalog.validate(entries, messages, "en")))
        self.assertNotEqual(catalog.placeholders("%s / %d"), catalog.placeholders("%d / %s"))

    def test_named_placeholders_can_be_reordered(self):
        self.assertEqual(catalog.placeholders("{name}, {count} laps"), catalog.placeholders("{count} tours, {name}"))

    def test_context_and_plural_extraction_respects_code_boundaries(self):
        text = '''# tr("Comment", "unused")
var example = "tr(\\"String\\")"
var action = tr("Close", "action")
var distance = GameText.message("Close", {}, "distance")
GameText.bind(label, "{count} lap", {"name": nested(1,2)}, "{count} laps", 2, "race")
'''
        entries = list(catalog.translation_calls(text))
        self.assertEqual([(source, many, context) for source, many, context, _ in entries],
                         [("Close", "", "action"), ("Close", "", "distance"), ("{count} lap", "{count} laps", "race")])

    def test_duplicate_and_incomplete_po_are_rejected(self):
        for source in ('msgid "Race"\nmsgstr "Course"\n\nmsgid "Race"\nmsgstr "Course"\n',
                       'msgid "Race"\n', '"orphan"\n'):
            with self.subTest(source=source), self.assertRaises(ValueError):
                catalog.parse_po(source)

    def test_fuzzy_untranslated_and_stale_copy_block_release(self):
        messages = {("", "Race"): {"plural": "", "references": set()}}
        source = catalog.render(messages, True)
        for changed in (source.replace('msgstr "Race"', 'msgstr ""'),
                        source.replace('msgid "Race"', '#, fuzzy\nmsgid "Race"'),
                        source.replace('msgid "Race"', 'msgid "Old race"')):
            self.assertTrue(catalog.validate(catalog.parse_po(changed), messages, "en"))

    def test_catalogue_is_current(self):
        messages = catalog.collect()
        self.assertTrue(catalog.source_catalogue_matches((catalog.DESTINATION / "messages.pot").read_text(encoding="utf-8"), messages))
        self.assertEqual(catalog.validate(catalog.parse_po((catalog.DESTINATION / "en.po").read_text(encoding="utf-8")), messages, "en"), [])

    def test_source_relocation_keeps_coverage_but_changed_copy_fails(self):
        messages = {("action", "Race"): {"plural": "", "references": {"ui.gd:10"}}}
        template = catalog.render(messages).replace("ui.gd:10", "ui.gd:200")
        self.assertTrue(catalog.source_catalogue_matches(template, messages))
        self.assertFalse(catalog.source_catalogue_matches(template.replace('msgid "Race"', 'msgid "Old race"'), messages))
        self.assertFalse(catalog.source_catalogue_matches(template.replace('msgctxt "action"', 'msgctxt "other"'), messages))
        messages[("action", "Race")]["plural"] = "Races"
        self.assertFalse(catalog.source_catalogue_matches(template, messages))


if __name__ == "__main__":
    unittest.main()
