"""Guard the authored translations independently of Godot's import cache."""
import unittest
import localization
import translate_catalogues as compiler


class AuthoringTests(unittest.TestCase):
    def test_every_authored_row_has_all_languages_and_preserves_values(self):
        for source, values in compiler.authored().items():
            self.assertEqual(set(values), set(compiler.LANGUAGES), source)
            for language, value in values.items():
                with self.subTest(source=source, language=language):
                    self.assertTrue(value.strip())
                    self.assertEqual(localization.placeholders(source), localization.placeholders(value))

    def test_missing_copy_is_explicit(self):
        self.assertIsNone(compiler.resolve("Unwritten copy must remain visibly incomplete", {}))

    def test_english_cognates_do_not_hide_missing_copy(self):
        self.assertIsNone(compiler.resolve("Continue", {}))
        self.assertIsNone(compiler.resolve("Race result", {}))
        self.assertIsNone(compiler.resolve("<1m left", {}))

    def test_brands_and_identifiers_keep_exact_spelling(self):
        for source in ("Beat My Track", "LanguageChoice", "VOLT / 07"):
            self.assertEqual(set(compiler.resolve(source, {}).values()), {source})

    def test_variants_keep_navigation_spacing(self):
        rows = compiler.authored()
        for language in compiler.LANGUAGES:
            self.assertEqual(compiler.resolve("Continue racing  ›", rows)[language], rows["Continue racing"][language] + " ›")

    def test_authored_label_templates_keep_value_placeholders(self):
        rows = compiler.authored()
        for source in ("Loading tracks…", "Reset camera", "Could not save controls."):
            result = compiler.resolve(source, rows)
            self.assertIsNotNone(result, source)
            for value in result.values():
                self.assertNotIn("{object}", value)
        self.assertTrue(compiler.resolve("Loading tracks…", rows)["ja"].endswith("読み込み中…"))

    def test_sentence_composition_keeps_layout_and_value_order(self):
        rows = compiler.authored()
        source = "Check your connection and try again.\nCould not save. Please try again."
        translated = compiler.resolve(source, rows)
        self.assertIsNotNone(translated)
        self.assertIn("\n", translated["ja"])
        self.assertNotIn("Could not", translated["ja"])
        self.assertEqual(localization.placeholders(source),localization.placeholders(translated["ja"]))


if __name__ == "__main__":
    unittest.main()
