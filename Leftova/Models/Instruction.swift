//
//  Instruction.swift
//  Leftova
//
//  Created by Zach Rich on 8/6/25.
//
import Foundation

struct Instruction: Codable, Identifiable, Hashable {
    let step: Int
    let text: String
    
    var id: Int { step }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(step)
    }
    
    static func == (lhs: Instruction, rhs: Instruction) -> Bool {
        lhs.step == rhs.step && lhs.text == rhs.text
    }
}
