//
// GrayGpuImageMacrosImpl
// Copyright © 2025 Seed Industrial Designing Co., Ltd. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software
// and associated documentation files (the “Software”), to deal in the Software without
// restriction, including without limitation the rights to use, copy, modify, merge, publish,
// distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom
// the Software is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all copies or
// substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//

import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

@main struct GrayGpuMacrosPlugin: CompilerPlugin
{
	let providingMacros: [Macro.Type] = [
		GrayGpuImageGeneratorMacro.self,
		GrayGpuImageFilterMacro.self,
	]
}

public protocol GrayGpuImageFunctionMacro: ExtensionMacro, MemberMacro
{
	static var protocolName: String { get }
	static var textureStartIndex: Int { get }
}
public struct GrayGpuImageGeneratorMacro: GrayGpuImageFunctionMacro
{
	public static let protocolName = "GrayGpuImageGenerator"
	public static let textureStartIndex = 1
}
public struct GrayGpuImageFilterMacro: GrayGpuImageFunctionMacro
{
	public static let protocolName = "GrayGpuImageFilter"
	public static let textureStartIndex = 2
}

//MARK: - ExtensionMacro

extension GrayGpuImageFunctionMacro
{
	public static func expansion(
		of node: AttributeSyntax,
		attachedTo declaration: some DeclGroupSyntax,
		providingExtensionsOf type: some TypeSyntaxProtocol,
		conformingTo protocols: [TypeSyntax],
		in context: some MacroExpansionContext
	) throws -> [ExtensionDeclSyntax]
	{
		guard let enumDecl = declaration.as(EnumDeclSyntax.self) else {
			return []
		}
		
		let alreadyConforms = enumDecl.inheritanceClause?.inheritedTypes.contains { inherited in
			inherited.type.trimmedDescription == protocolName
		} ?? false
		if alreadyConforms {
			return []
		} else { // Add conformance
			let ext: DeclSyntax = """
 extension \(type.trimmed): \(raw: protocolName) {}
 """
			return [ext.cast(ExtensionDeclSyntax.self)]
		}
	}
}

//MARK: - MemberMacro

extension GrayGpuImageFunctionMacro
{
	public static func expansion(
		of node: AttributeSyntax,
		providingMembersOf declaration: some DeclGroupSyntax,
		in context: some MacroExpansionContext
	) throws -> [DeclSyntax]
	{
		guard let enumDecl = declaration.as(EnumDeclSyntax.self) else {
			throw MacroError.notAnEnum
		}
		
		let cases = enumDecl.memberBlock.members.compactMap { member -> EnumCaseElementSyntax? in
			guard let caseDecl = member.decl.as(EnumCaseDeclSyntax.self) else { return nil }
			return caseDecl.elements.first
		}
		guard !cases.isEmpty else {
			throw MacroError.noCases
		}
		
		var result: [DeclSyntax] = []; do {
			// 1. bundle プロパティを生成
			let containsBundleProperty = enumDecl.memberBlock.members.contains { member in
				guard let varDecl = member.decl.as(VariableDeclSyntax.self) else { return false }
				return varDecl.bindings.contains { $0.pattern.as(IdentifierPatternSyntax.self)?.identifier.text == "bundle" }
			}
			if !containsBundleProperty {
				let bundlePropertyDecl = try generateBundleProperty()
				result.append(bundlePropertyDecl)
			}
			
			// 2. functionDescriptors プロパティを生成
			let functionDescriptorsDecl = try generateFunctionDescriptors(cases: cases)
			result.append(functionDescriptorsDecl)
			
			// 3. name プロパティを生成
			let namePropertyDecl = try generateNameProperty(cases: cases)
			result.append(namePropertyDecl)
			
			// 4. setupComputeEncoder メソッドを生成
			let setupMethodDecl = try generateSetupMethod(cases: cases)
			result.append(setupMethodDecl)
		}
		return result
	}
	
	private static func generateBundleProperty() throws -> DeclSyntax
	{
		return """
 #if SWIFT_PACKAGE
 public static var bundle = Bundle.module
 #else
 private final class EmptyClass {}
 public static var bundle = Bundle(for: EmptyClass.self)
 #endif
 """
	}
	
	private static func generateFunctionDescriptors(cases: [EnumCaseElementSyntax]) throws -> DeclSyntax
	{
		let caseNames = cases.map { caseName($0) }
		let arrayElements = caseNames.map { "\t\t\t.init(bundle: bundle, name: \"\($0)\")" }.joined(separator: ",\n")
		
		return """
 public static var functionDescriptors: [GrayGpuContext.FunctionDescriptor]
 {
     [
  \(raw: arrayElements)
     ]
 }
 """
	}
	
	private static func generateNameProperty(cases: [EnumCaseElementSyntax]) throws -> DeclSyntax
	{
		var switchCases: [String] = []
		
		for caseElement in cases {
			let name = caseName(caseElement)
			let pattern = generateCasePattern(caseElement, defineVariables: false)
			switchCases.append("case \(pattern):\n\t\t\t\t\"\(name)\"")
		}
		
		return """
var name: String
{
    switch self {
    \(raw: switchCases.map { "\t\t\t" + $0 }.joined(separator: "\n"))
    }
}
"""
	}
	
	private static func generateSetupMethod(cases: [EnumCaseElementSyntax]) throws -> DeclSyntax
	{
		var switchCases: [String] = []
		
		for caseElement in cases {
			let pattern = generateCasePattern(caseElement, defineVariables: true)
			let body = generateSetupBody(caseElement)
			
			switchCases.append("""
     case \(pattern):
     \(body)
     """)
		}
		
		return """
public func setupComputeEncoder(_ encoder: MTLComputeCommandEncoder, context: GrayGpuContext) throws
{
    let pipelineState = try context.pipelineState(for: .init(bundle: Self.bundle, name: name))!
    encoder.setComputePipelineState(pipelineState)
    switch self {
 \(raw: switchCases.map { "\t\t\t" + $0 }.joined(separator: "\n"))
    }
}
"""
	}
	
	private static func caseName(_ caseElement: EnumCaseElementSyntax) -> String
	{
		caseElement.name.text
	}
	
	private static func generateCasePattern(_ caseElement: EnumCaseElementSyntax, defineVariables: Bool) -> String
	{
		let name = caseName(caseElement)
		
		guard let params = caseElement.parameterClause else {
			return ".\(name)"
		}
		
		let bindings = params.parameters.map { param in
			let label = param.firstName?.text ?? "_"
			return (defineVariables ? "\(label): let \(label)" : "\(label): _")
		}.joined(separator: ", ")
		
		return ".\(name)(\(bindings))"
	}
	
	private static func generateSetupBody(_ caseElement: EnumCaseElementSyntax) -> String
	{
		guard let params = caseElement.parameterClause else {
			return "\t\t\t\t// No parameters"
		}
		
		var lines: [String] = []
		var bufferIndex = 0
		var textureIndex = Self.textureStartIndex
		
		for param in params.parameters {
			let label = param.firstName?.text ?? "_"
			let typeText = param.type.description.trimmingCharacters(in: .whitespaces)
			
			switch typeText {
			case "MTLTexture":
				// MTLTexture の場合は setTexture を使用
				lines.append("encoder.setTexture(\(label), index: \(textureIndex))")
				textureIndex += 1
			case "UnsafeRawBufferPointer":
				// その他の型は setBytes を使用
				lines.append("encoder.setBytes(\(label).baseAddress, length: \(label).count, index: \(bufferIndex))")
				bufferIndex += 1
			default:
				let (metalValueLength, conversion) = convertType(swiftType: typeText, varName: label)
				lines.append("var \(label)_metal = \(conversion)")
				lines.append("encoder.setBytes(&\(label)_metal, length: \(metalValueLength), index: \(bufferIndex))")
				bufferIndex += 1
			}
		}
		
		return lines.map { "\t\t\t\t" + $0 }.joined(separator: "\n")
	}
	
	private static func convertType(swiftType: String, varName: String) -> (metalTypeLength: String, conversion: String)
	{
		switch swiftType {
		case _ where swiftType.starts(with: "SIMD"):
			("MemoryLayout<\(swiftType)>.size", varName)
		default:
			("\(varName).metalValueLength", "\(varName).metalValue")
		}
	}
}

//MARK: - Error

enum MacroError: Error, CustomStringConvertible
{
	case notAnEnum
	case noCases
	
	var description: String
	{
		switch self {
		case .notAnEnum:
			return "@GrayGpuImageFilter can only be applied to enums"
		case .noCases:
			return "Enum must have at least one case"
		}
	}
}
