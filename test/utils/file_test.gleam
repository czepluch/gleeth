import gleeth/rpc/types
import gleeth/utils/file
import gleeunit
import gleeunit/should
import simplifile

pub fn main() {
  gleeunit.main()
}

/// Test reading addresses from file
pub fn read_addresses_test() {
  let content =
    "0x742dBF0b6d9bAA31b82BB5bcB6e0e1C7a5b30000
# comment line
0x1111111111111111111111111111111111111111"

  let filename = "test_addresses.txt"
  let _ = simplifile.write(filename, content)

  let result = file.read_addresses_from_file(filename)
  let _ = simplifile.delete(filename)

  case result {
    Ok(addresses) -> {
      should.equal(addresses, [
        "0x742dBF0b6d9bAA31b82BB5bcB6e0e1C7a5b30000",
        "0x1111111111111111111111111111111111111111",
      ])
    }
    Error(_) -> should.fail()
  }
}

/// Test file not found error
pub fn read_addresses_not_found_test() {
  let result = file.read_addresses_from_file("non_existent_file.txt")

  case result {
    Error(types.ConfigError(_)) -> Nil
    _ -> should.fail()
  }
}
