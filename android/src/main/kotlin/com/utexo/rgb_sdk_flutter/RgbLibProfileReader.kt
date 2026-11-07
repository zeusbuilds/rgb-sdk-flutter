package com.utexo.rgb_sdk_flutter

import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileInputStream
import java.io.IOException
import java.nio.ByteBuffer
import java.nio.charset.CodingErrorAction
import org.json.JSONException
import org.json.JSONObject

internal class RgbLibProfileReadException : Exception()

/** Bounded metadata admission shared by normal open and encrypted restore. */
internal object RgbLibProfileReader {
  const val MAX_BYTES = 65536

  fun read(file: File): JSONObject {
    try {
      if (file.canonicalFile != file.absoluteFile || !file.isFile || file.length() > MAX_BYTES)
        throw RgbLibProfileReadException()
      val bytes = FileInputStream(file).use { input ->
        if (input.channel.size() > MAX_BYTES) throw RgbLibProfileReadException()
        val output = ByteArrayOutputStream(4096)
        val buffer = ByteArray(4096)
        while (true) {
          val count = input.read(buffer)
          if (count < 0) break
          if (count > MAX_BYTES - output.size()) throw RgbLibProfileReadException()
          output.write(buffer, 0, count)
        }
        output.toByteArray()
      }
      val text = Charsets.UTF_8.newDecoder()
        .onMalformedInput(CodingErrorAction.REPORT)
        .onUnmappableCharacter(CodingErrorAction.REPORT)
        .decode(ByteBuffer.wrap(bytes)).toString()
      if (text.indexOf('\u0000') >= 0) throw RgbLibProfileReadException()
      FlatProfile(text).validate()
      return JSONObject(text)
    } catch (error: RgbLibProfileReadException) { throw error }
    catch (_: IOException) { throw RgbLibProfileReadException() }
    catch (_: JSONException) { throw RgbLibProfileReadException() }
  }

  // Format2 metadata is flat. Validate strict JSON before Android's lenient
  // JSONObject parser can accept comments, unquoted/single-quoted strings or
  // recursively parse an attacker-supplied container. This parser never recurses.
  private class FlatProfile(private val text: String) {
    private var cursor = 0
    private fun invalid(): Nothing = throw RgbLibProfileReadException()
    private fun peek(): Char = if (cursor < text.length) text[cursor] else '\u0000'
    private fun take(value: Char): Boolean = if (peek() == value) { cursor++; true } else false
    private fun required(value: Char) { if (!take(value)) invalid() }
    private fun whitespace() { while (peek() in listOf(' ', '\t', '\r', '\n')) cursor++ }
    private fun digit(value: Char) = value in '0'..'9'
    private fun unicodeEscape(): Int {
      var value = 0
      repeat(4) {
        if (cursor >= text.length) invalid()
        val hex = "0123456789abcdef".indexOf(text[cursor++].lowercaseChar())
        if (hex < 0) invalid()
        value = value * 16 + hex
      }
      return value
    }
    private fun quotedString() {
      required('"')
      while (cursor < text.length) {
        val code = text[cursor++]
        if (code == '"') return
        if (code.code < 32) invalid()
        if (code == '\\') {
          if (cursor >= text.length) invalid()
          when (text[cursor++]) {
            '"', '\\', '/', 'b', 'f', 'n', 'r', 't' -> Unit
            'u' -> {
              val unit = unicodeEscape()
              if (unit in 0xd800..0xdbff) {
                required('\\'); required('u')
                if (unicodeEscape() !in 0xdc00..0xdfff) invalid()
              } else if (unit in 0xdc00..0xdfff) invalid()
            }
            else -> invalid()
          }
        }
      }
      invalid()
    }
    private fun literal(value: String) {
      if (!text.regionMatches(cursor, value, 0, value.length)) invalid()
      cursor += value.length
    }
    private fun number() {
      val start = cursor
      take('-')
      if (take('0')) {
        if (digit(peek())) invalid()
      } else {
        if (peek() !in '1'..'9') invalid()
        while (digit(peek())) cursor++
      }
      if (take('.')) {
        if (!digit(peek())) invalid()
        while (digit(peek())) cursor++
      }
      if (peek() == 'e' || peek() == 'E') {
        cursor++
        if (!take('+')) take('-')
        if (!digit(peek())) invalid()
        while (digit(peek())) cursor++
      }
      if (cursor - start > 24) invalid()
      if (text.substring(start, cursor).toDoubleOrNull()?.isFinite() != true) invalid()
    }
    private fun scalar() {
      when (peek()) {
        '"' -> quotedString()
        't' -> literal("true")
        'f' -> literal("false")
        'n' -> literal("null")
        else -> number()
      }
    }
    fun validate() {
      whitespace(); required('{'); whitespace()
      if (!take('}')) {
        while (true) {
          quotedString(); whitespace(); required(':'); whitespace(); scalar(); whitespace()
          if (take('}')) break
          required(','); whitespace()
        }
      }
      whitespace()
      if (cursor != text.length) invalid()
    }
  }
}
