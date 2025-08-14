import gleeunit
import gleeunit/should
import simplifile
import gleeth/utils/file
import gleeth/rpc/types

pub fn main() {
  gleeunit.main()
}

// Test reading addresses from a well-formed file
pub fn read_addresses_success_test() {
  let content = "0x742dBF0b6d9bAA31b82BB5bcB6e0e1C7a5b30000
0x1111111111111111111111111111111111111111
0x2222222222222222222222222222222222222222"
  
  let filename = "test_addresses.txt"
  let _ = simplifile.write(filename, content)
  
  let result = file.read_addresses_from_file(filename)
  let _ = simplifile.delete(filename)
  
  case result {
    Ok(addresses) -> {
      should.equal(addresses, [
        "0x742dBF0b6d9bAA31b82BB5bcB6e0e1C7a5b30000",
        "0x1111111111111111111111111111111111111111",
        "0x2222222222222222222222222222222222222222"
      ])
    }
    Error(_) -> should.be_true(False)
  }
}

// Test reading addresses with comments and empty lines
pub fn read_addresses_with_comments_test() {
  let content = "# This is a comment
0x742dBF0b6d9bAA31b82BB5bcB6e0e1C7a5b30000

# Another comment
0x1111111111111111111111111111111111111111

# Empty lines above should be ignored
0x2222222222222222222222222222222222222222"
  
  let filename = "test_comments.txt"
  let _ = simplifile.write(filename, content)
  
  let result = file.read_addresses_from_file(filename)
  let _ = simplifile.delete(filename)
  
  case result {
    Ok(addresses) -> {
      should.equal(addresses, [
        "0x742dBF0b6d9bAA31b82BB5bcB6e0e1C7a5b30000",
        "0x1111111111111111111111111111111111111111",
        "0x2222222222222222222222222222222222222222"
      ])
    }
    Error(_) -> should.be_true(False)
  }
}

// Test reading addresses without 0x prefix (should be added automatically)
pub fn read_addresses_no_prefix_test() {
  let content = "742dBF0b6d9bAA31b82BB5bcB6e0e1C7a5b30000
1111111111111111111111111111111111111111"
  
  let filename = "test_no_prefix.txt"
  let _ = simplifile.write(filename, content)
  
  let result = file.read_addresses_from_file(filename)
  let _ = simplifile.delete(filename)
  
  case result {
    Ok(addresses) -> {
      should.equal(addresses, [
        "0x742dBF0b6d9bAA31b82BB5bcB6e0e1C7a5b30000",
        "0x1111111111111111111111111111111111111111"
      ])
    }
    Error(_) -> should.be_true(False)
  }
}

// Test reading from non-existent file
pub fn read_addresses_file_not_found_test() {
  let result = file.read_addresses_from_file("non_existent_file.txt")
  
  case result {
    Error(types.ConfigError(_)) -> should.be_true(True)
    _ -> should.be_true(False)
  }
}

// Test reading empty file
pub fn read_addresses_empty_file_test() {
  let filename = "test_empty.txt"
  let _ = simplifile.write(filename, "")
  
  let result = file.read_addresses_from_file(filename)
  let _ = simplifile.delete(filename)
  
  case result {
    Error(types.ConfigError(_)) -> should.be_true(True)
    _ -> should.be_true(False)
  }
}

// Test reading file with only comments
pub fn read_addresses_only_comments_test() {
  let content = "# Comment 1
# Comment 2
# Comment 3"
  
  let filename = "test_only_comments.txt"
  let _ = simplifile.write(filename, content)
  
  let result = file.read_addresses_from_file(filename)
  let _ = simplifile.delete(filename)
  
  case result {
    Error(types.ConfigError(_)) -> should.be_true(True)
    _ -> should.be_true(False)
  }
}

// Test reading file with invalid addresses
pub fn read_addresses_invalid_test() {
  let content = "0x742dBF0b6d9bAA31b82BB5bcB6e0e1C7a5b30000
invalid_address
0x1111111111111111111111111111111111111111"
  
  let filename = "test_invalid.txt"
  let _ = simplifile.write(filename, content)
  
  let result = file.read_addresses_from_file(filename)
  let _ = simplifile.delete(filename)
  
  case result {
    Error(types.InvalidAddress(_)) -> should.be_true(True)
    _ -> should.be_true(False)
  }
}

// Test reading file with mixed case addresses
pub fn read_addresses_mixed_case_test() {
  let content = "0x742dbf0b6d9baa31b82bb5bcb6e0e1c7a5b30000
0x1111111111111111111111111111111111111111"
  
  let filename = "test_mixed_case.txt"
  let _ = simplifile.write(filename, content)
  
  let result = file.read_addresses_from_file(filename)
  let _ = simplifile.delete(filename)
  
  case result {
    Ok(addresses) -> {
      should.equal(addresses, [
        "0x742dbf0b6d9baa31b82bb5bcb6e0e1c7a5b30000",
        "0x1111111111111111111111111111111111111111"
      ])
    }
    Error(_) -> should.be_true(False)
  }
}