package com.utexo.rgb_sdk_flutter

import java.io.File
import java.nio.file.Files
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith

internal class RgbLibProfileReaderTest {
  @Test fun boundedScalarProfileAllowsExactLimitAndRejectsOversizeBeforeParsing() {
    val dir = Files.createTempDirectory("rgb-profile-reader").toFile().canonicalFile
    try {
      val file = File(dir, "profile.json")
      val exact = "{}" + " ".repeat(RgbLibProfileReader.MAX_BYTES - 2)
      file.writeText(exact)
      assertEquals(0, RgbLibProfileReader.read(file).length())
      file.appendText(" ")
      assertFailsWith<RgbLibProfileReadException> { RgbLibProfileReader.read(file) }
      assertEquals(exact + " ", file.readText())
    } finally { dir.deleteRecursively() }
  }

  @Test fun malformedNonobjectAndDeepJsonRemainTypedWithoutChangingFiles() {
    val dir = Files.createTempDirectory("rgb-profile-reader").toFile().canonicalFile
    try {
      val file = File(dir, "profile.json")
      for (value in listOf("{broken", "[]", "null", "\"string\"",
        "{\"v\":" + "[".repeat(32000) + "0" + "]".repeat(32000) + "}",
        "{/*\"*/\"x\":" + "[".repeat(1000) + "0" + "]".repeat(1000) + "/*\"*/}",
        "{x:'value'}", "{\"x\":NaN}", "{\"x\":01}", "{\"x\":1,}",
        "{\"x\":1234567890123456789012345}", "{\"x\":1e999}",
        "{\"x\":\"bad\\xescape\"}", "{\"x\":\"\\uD800\"}", "{\"x\":\"\\uDC00\"}")) {
        file.writeText(value)
        assertFailsWith<RgbLibProfileReadException> { RgbLibProfileReader.read(file) }
        assertEquals(value, file.readText())
      }
      val text = "[\"\\".repeat(100)
      file.writeText(org.json.JSONObject().put("text", text).toString())
      assertEquals(text, RgbLibProfileReader.read(file).getString("text"))
    } finally { dir.deleteRecursively() }
  }

  @Test fun onlyRegularNonaliasProfileFilesAreAdmitted() {
    val dir = Files.createTempDirectory("rgb-profile-reader").toFile().canonicalFile
    try {
      val file = File(dir, "profile.json").apply { writeText("{}") }
      val link = File(dir, "alias.json")
      Files.createSymbolicLink(link.toPath(), file.toPath())
      assertFailsWith<RgbLibProfileReadException> { RgbLibProfileReader.read(link) }
      assertFailsWith<RgbLibProfileReadException> { RgbLibProfileReader.read(dir) }
      assertFailsWith<RgbLibProfileReadException> { RgbLibProfileReader.read(File(dir, "absent")) }
      assertEquals("{}", file.readText())
    } finally { dir.deleteRecursively() }
  }

  @Test fun nonUtf8MetadataCannotUseAnotherDecodedGrammar() {
    val dir = Files.createTempDirectory("rgb-profile-reader").toFile().canonicalFile
    try {
      val file = File(dir, "profile.json")
      for (bytes in listOf("{\"x\":1}".toByteArray(Charsets.UTF_16),
        byteArrayOf(123, 34, 120, 34, 58, 34, 0xc0.toByte(), 0xaf.toByte(), 34, 125))) {
        file.writeBytes(bytes)
        assertFailsWith<RgbLibProfileReadException> { RgbLibProfileReader.read(file) }
        kotlin.test.assertContentEquals(bytes, file.readBytes())
      }
    } finally { dir.deleteRecursively() }
  }
}
