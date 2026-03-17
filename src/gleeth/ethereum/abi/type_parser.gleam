import gleam/int
import gleam/list
import gleam/result
import gleam/string
import gleeth/ethereum/abi/types.{type AbiError, type AbiType}

/// Parse a Solidity type string into an AbiType.
/// Handles: uint<N>, int<N>, address, bool, bytes<N>, bytes, string,
/// <type>[], <type>[N], (<type>,<type>,...).
pub fn parse(type_string: String) -> Result(AbiType, AbiError) {
  let trimmed = string.trim(type_string)
  case trimmed {
    "" -> Error(types.TypeParseError("Empty type string"))
    _ -> parse_type(trimmed)
  }
}

fn parse_type(s: String) -> Result(AbiType, AbiError) {
  // Handle tuple types starting with '('
  case string.starts_with(s, "(") {
    True -> parse_with_array_suffix(s)
    False -> parse_with_array_suffix(s)
  }
}

/// Parse a type, then consume any trailing [] or [N] suffixes.
fn parse_with_array_suffix(s: String) -> Result(AbiType, AbiError) {
  use #(base, rest) <- result.try(parse_base_type(s))
  apply_array_suffixes(base, rest)
}

/// Parse the base type (before any array suffixes).
/// Returns the parsed type and any remaining unparsed string.
fn parse_base_type(s: String) -> Result(#(AbiType, String), AbiError) {
  case s {
    "(" <> _ -> parse_tuple(s)
    "uint" <> rest -> parse_int_type(rest, True)
    "int" <> rest -> parse_int_type(rest, False)
    "address" <> rest -> Ok(#(types.Address, rest))
    "bool" <> rest -> Ok(#(types.Bool, rest))
    "bytes" <> rest -> parse_bytes_type(rest)
    "string" <> rest -> Ok(#(types.String, rest))
    _ -> Error(types.TypeParseError("Unknown type: " <> s))
  }
}

/// Parse uint<N> or int<N>. The prefix "uint"/"int" has already been consumed.
fn parse_int_type(
  rest: String,
  unsigned: Bool,
) -> Result(#(AbiType, String), AbiError) {
  let #(digits, remaining) = take_digits(rest)
  case digits {
    "" -> {
      // Bare "uint" or "int" means 256
      let t = case unsigned {
        True -> types.Uint(256)
        False -> types.Int(256)
      }
      Ok(#(t, remaining))
    }
    _ -> {
      use size <- result.try(
        int.parse(digits)
        |> result.map_error(fn(_) {
          types.TypeParseError("Invalid integer size: " <> digits)
        }),
      )
      case size >= 8 && size <= 256 && size % 8 == 0 {
        True -> {
          let t = case unsigned {
            True -> types.Uint(size)
            False -> types.Int(size)
          }
          Ok(#(t, remaining))
        }
        False ->
          Error(types.TypeParseError(
            "Integer size must be 8-256 in steps of 8, got: "
            <> int.to_string(size),
          ))
      }
    }
  }
}

/// Parse bytes or bytes<N>. The prefix "bytes" has already been consumed.
fn parse_bytes_type(rest: String) -> Result(#(AbiType, String), AbiError) {
  let #(digits, remaining) = take_digits(rest)
  case digits {
    "" -> Ok(#(types.Bytes, remaining))
    _ -> {
      use size <- result.try(
        int.parse(digits)
        |> result.map_error(fn(_) {
          types.TypeParseError("Invalid bytes size: " <> digits)
        }),
      )
      case size >= 1 && size <= 32 {
        True -> Ok(#(types.FixedBytes(size), remaining))
        False ->
          Error(types.TypeParseError(
            "Fixed bytes size must be 1-32, got: " <> int.to_string(size),
          ))
      }
    }
  }
}

/// Parse a tuple type: (T1,T2,...). Handles nested parentheses.
fn parse_tuple(s: String) -> Result(#(AbiType, String), AbiError) {
  // s starts with '('
  let inner_and_rest = string.drop_start(s, 1)
  use #(inner, after_paren) <- result.try(find_matching_paren(
    inner_and_rest,
    0,
    "",
  ))
  // Split inner by commas at depth 0
  use element_strings <- result.try(split_at_top_level_commas(inner))
  case element_strings {
    // Empty tuple ()
    [""] -> Ok(#(types.Tuple([]), after_paren))
    _ -> {
      use elements <- result.try(list.try_map(element_strings, parse))
      Ok(#(types.Tuple(elements), after_paren))
    }
  }
}

/// Find the matching ')' accounting for nested parens.
/// Returns (content_inside_parens, rest_after_closing_paren).
fn find_matching_paren(
  s: String,
  depth: Int,
  acc: String,
) -> Result(#(String, String), AbiError) {
  case string.pop_grapheme(s) {
    Error(_) -> Error(types.TypeParseError("Unmatched opening parenthesis"))
    Ok(#(")", rest)) -> {
      case depth {
        0 -> Ok(#(acc, rest))
        _ -> find_matching_paren(rest, depth - 1, acc <> ")")
      }
    }
    Ok(#("(", rest)) -> find_matching_paren(rest, depth + 1, acc <> "(")
    Ok(#(ch, rest)) -> find_matching_paren(rest, depth, acc <> ch)
  }
}

/// Split a string by commas, but only at parenthesis depth 0.
fn split_at_top_level_commas(s: String) -> Result(List(String), AbiError) {
  split_commas_impl(s, 0, "", [])
}

fn split_commas_impl(
  s: String,
  depth: Int,
  current: String,
  acc: List(String),
) -> Result(List(String), AbiError) {
  case string.pop_grapheme(s) {
    Error(_) -> Ok(list.reverse([current, ..acc]))
    Ok(#(",", rest)) -> {
      case depth {
        0 -> split_commas_impl(rest, 0, "", [current, ..acc])
        _ -> split_commas_impl(rest, depth, current <> ",", acc)
      }
    }
    Ok(#("(", rest)) -> split_commas_impl(rest, depth + 1, current <> "(", acc)
    Ok(#(")", rest)) -> split_commas_impl(rest, depth - 1, current <> ")", acc)
    Ok(#(ch, rest)) -> split_commas_impl(rest, depth, current <> ch, acc)
  }
}

/// Apply trailing array suffixes: [] or [N]
fn apply_array_suffixes(
  base: AbiType,
  rest: String,
) -> Result(AbiType, AbiError) {
  case string.starts_with(rest, "[") {
    False -> {
      case rest {
        "" -> Ok(base)
        _ ->
          Error(types.TypeParseError("Unexpected trailing characters: " <> rest))
      }
    }
    True -> {
      let after_bracket = string.drop_start(rest, 1)
      use #(size_str, after_close) <- result.try(take_until_close_bracket(
        after_bracket,
        "",
      ))
      case size_str {
        "" -> {
          // Dynamic array: T[]
          apply_array_suffixes(types.Array(base), after_close)
        }
        _ -> {
          // Fixed array: T[N]
          use size <- result.try(
            int.parse(size_str)
            |> result.map_error(fn(_) {
              types.TypeParseError("Invalid array size: " <> size_str)
            }),
          )
          apply_array_suffixes(types.FixedArray(base, size), after_close)
        }
      }
    }
  }
}

fn take_until_close_bracket(
  s: String,
  acc: String,
) -> Result(#(String, String), AbiError) {
  case string.pop_grapheme(s) {
    Error(_) -> Error(types.TypeParseError("Unmatched '[' in type"))
    Ok(#("]", rest)) -> Ok(#(acc, rest))
    Ok(#(ch, rest)) -> take_until_close_bracket(rest, acc <> ch)
  }
}

/// Take leading digits from a string, return (digits, rest).
fn take_digits(s: String) -> #(String, String) {
  take_digits_impl(s, "")
}

fn take_digits_impl(s: String, acc: String) -> #(String, String) {
  case string.pop_grapheme(s) {
    Error(_) -> #(acc, "")
    Ok(#(ch, rest)) -> {
      case is_digit(ch) {
        True -> take_digits_impl(rest, acc <> ch)
        False -> #(acc, ch <> rest)
      }
    }
  }
}

fn is_digit(ch: String) -> Bool {
  case ch {
    "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9" -> True
    _ -> False
  }
}
