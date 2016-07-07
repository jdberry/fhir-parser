//
//  FHIRAbstractBase.swift
//  SwiftFHIR
//
//  Created by Pascal Pfiffner on 7/2/14.
//  2014, SMART Health IT.
//


/**
 *  Abstract superclass for all FHIR data elements.
 */
public class FHIRAbstractBase: CustomStringConvertible {
	
	/// The name of the resource or element.
	public class var resourceName: String {
		get { return "FHIRAbstractBase" }
	}
	
	/// The parent/owner of the receiver, if any. Used to dereference resources.
	weak var _owner: FHIRAbstractBase?
	
	/// Resolved references.
	var _resolved: [String: Resource]?
	
	
	/**
	The default initializer.
		
	Forwards to `populate(fromJSON:)` and logs all JSON errors to console, if "DEBUG" is defined and true.
	*/
	public required init(json: FHIRJSON?, owner: FHIRAbstractBase? = nil) {
		_owner = owner
		if let errors = populate(fromJSON: json) {
			for error in errors {
				fhir_warn(error.description)
			}
		}
	}
	
	
	// MARK: - JSON Capabilities
	
	/**
	Will populate instance variables - overriding existing ones - with values found in the supplied JSON.
	
	- parameter fromJSON: The JSON dictionary to pull data from
	- returns:            An optional array of errors reporting missing (when nonoptional) and superfluous properties and properties of the
	                      wrong type
	*/
	public final func populate(fromJSON json: FHIRJSON?) -> [FHIRJSONError]? {
		var present = Set<String>()
		present.insert("fhir_comments")
		var errors = populate(fromJSON: json, presentKeys: &present) ?? [FHIRJSONError]()
		
		// superfluous JSON entries? Ignore "fhir_comments" and "_xy".
		let superfluous = json?.keys.filter() { !present.contains($0) }
		if let supflu = superfluous where !supflu.isEmpty {
			for sup in supflu {
				if let first = sup.characters.first where "_" != first {
					errors.append(FHIRJSONError(key: sup, has: json![sup]!.dynamicType))
				}
			}
		}
		return errors.isEmpty ? nil : errors
	}
	
	/**
	The main function to perform the actual JSON parsing, to be overridden by subclasses.
	 
	- parameter fromJSON:    The JSON element to use to populate the receiver
	- parameter presentKeys: An in-out parameter being filled with key names used.
	- returns:               An optional array of errors reporting missing mandatory keys or keys containing values of the wrong type
	*/
	public func populate(fromJSON: FHIRJSON?, presentKeys: inout Set<String>) -> [FHIRJSONError]? {
		return nil
	}
	
	/**
	Represent the receiver in FHIRJSON, ready to be used for JSON serialization.
	
	- returns: The FHIRJSON reperesentation of the receiver
	*/
	public func asJSON() -> FHIRJSON {
		return FHIRJSON()
	}
	
	/**
	Calls `asJSON()` on all elements in the array and returns the resulting array full of FHIRJSON dictionaries.
	
	- parameter array: The array of elements to map to FHIRJSON
	- returns:         An array of FHIRJSON elements representing the given resources
	*/
	public class func asJSONArray(_ array: [FHIRAbstractBase]) -> [FHIRJSON] {
		return array.map() { $0.asJSON() }
	}
	
	
	// MARK: - Factories
	
	/**
	Tries to find `resourceType` by inspecting the JSON dictionary, then instantiates the appropriate class for the
	specified resource type, or instantiates the receiver's class otherwise.
	
	- parameter fromJSON: A FHIRJSON decoded from a JSON response
	- parameter owner:    The FHIRAbstractBase owning the new instance, if appropriate
	- returns:            If possible the appropriate FHIRAbstractBase subclass, instantiated from the given JSON dictionary, Self otherwise
	*/
	public final class func instantiate(fromJSON json: FHIRJSON?, owner: FHIRAbstractBase?) -> FHIRAbstractBase {
		if let type = json?["resourceType"] as? String {
			return factory(type, json: json!, owner: owner)
		}
		let instance = self.init(json: json)		// must use 'required' init with dynamic type
		instance._owner = owner
		return instance
	}
	
	/**
	Instantiates an array of the receiver's type and returns it.
	
	- parameter fromArray: The FHIRJSON array to instantiate from
	- parameter owner:     The FHIRAbstractBase owning the new instance, if appropriate
	- returns:             An array of the appropriate FHIRAbstractBase subclass, if possible, Self otherwise
	*/
	public final class func instantiate(fromArray: [FHIRJSON], owner: FHIRAbstractBase? = nil) -> [FHIRAbstractBase] {
		return fromArray.map() { instantiate(fromJSON: $0, owner: owner) }
	}
	
	
	// MARK: - Resolving References
	
	/** Returns the resolved reference with the given id, if it has been resolved already. */
	public func resolvedReference(_ refid: String) -> Resource? {
		if let resolved = _resolved?[refid] {
			return resolved
		}
		return _owner?.resolvedReference(refid)
	}
	
	/**
	Stores the resolved reference into the `_resolved` dictionary.
	
	This method is public because it's used in an extension in our client. You likely don't need to use it explicitly, use the
	`resolve(type:callback:)` method on `Reference` instead.
	
	- parameter refid: The reference identifier as String
	- parameter resolved: The resource that was resolved
	*/
	public func didResolveReference(_ refid: String, resolved: Resource) {
		if nil != _resolved {
			_resolved![refid] = resolved
		}
		else {
			_resolved = [refid: resolved]
		}
	}
	
	/**
	The resource owning the receiver; used during reference resolving and to look up the instance's `_server`, if any.
	
	- returns: The owning `DomainResource` instance or nil
	*/
	public var owningResource: DomainResource? {
		var owner = _owner
		while nil != owner {
			if let owner = owner as? DomainResource {
				return owner
			}
			owner = owner?._owner
		}
		return nil
	}
	
	/**
	Returns the receiver's owning Bundle, if it has one.
	
	- returns: The owning `Bundle` instance or nil
	*/
	public var owningBundle: Bundle? {
		var owner = _owner
		while nil != owner {
			if let owner = owner as? Bundle {
				return owner
			}
			owner = owner?._owner
		}
		return nil
	}
	
	
	// MARK: - Printable
	
	public var description: String {
		return "<\(self.dynamicType.resourceName)>"
	}
}

