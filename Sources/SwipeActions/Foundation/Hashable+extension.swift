import Foundation

extension Hashable {
    var uuid: UUID {

        let hashValue = self.hashValue
        
        // converting hash value to byte array:
        var hashBytes = withUnsafeBytes(of: hashValue.bigEndian) { Array($0) }
        
        // UUID requires 128 bits, filling the remaining bytes with zeros
        hashBytes += Array(repeating: 0, count: 16 - hashBytes.count)
        
        // now we can create UUID:
        let uuid = UUID( uuid: (
            hashBytes[0], hashBytes[1], hashBytes[2], hashBytes[3],
            hashBytes[4], hashBytes[5], hashBytes[6], hashBytes[7],
            hashBytes[8], hashBytes[9], hashBytes[10], hashBytes[11],
            hashBytes[12], hashBytes[13], hashBytes[14], hashBytes[15]
        ))
        
        return uuid
    }
}
