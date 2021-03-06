//
//  PostgreStORM.swift
//  PostgresSTORM
//
//  Created by Jonathan Guthrie on 2016-10-03.
//
//

import StORM
import MongoKitten
import PerfectLogger
import Foundation
#if os(Linux)
import LinuxBridge
#endif

/// MongoDBConnection sets the connection parameters for the MongoDB Server access
/// Usage: 
/// MongoDBConnection.host = "XXXXXX"
/// MongoDBConnection.port = 5984
/// MongoDBConnection.ssl = true
/// MongoDBConnection.authmode = .standard
/// MongoDBConnection.username = "XXXXXX"
/// MongoDBConnection.password = "XXXXXX"
/// MongoDBConnection.authdb = "authusers"
public struct MongoDBConnection {

	public static var host: String		= "localhost"
	public static var port: UInt16		= 27017
	public static var ssl: Bool			= false

	public static var username: String	= ""
	public static var password: String	= ""
	public static var authdb: String	= ""

	/// Database param is used as default if none specified in calls
	public static var database: String	= ""

	private init(){}
}

/// A "superclass" that is meant to be inherited from by oject classes.
/// Provides ORM structre.
open class MongoDBStORM: StORM, StORMProtocol {
    public static var client: MongoKitten.Server?

	/// Database to be used for this object
	public var _database = MongoDBConnection.database

	/// Collection object that the child object relates to on the MongoDB server.
	/// Defined as "var" as it is meant to be overridden by the child class.
	/// Note this varies from the standard StORM terminology to be more familiar to MongoDB users
	public var _collection = "unset"

	/// Aliasing the _collection var. Here for compatability with other StORM usages
	public func table() -> String {
		return _collection
	}

	/// Base initializer method.
	override public init() {
		super.init()
	}

	private func printDebug(_ statement: String, _ params: [String]) {
		if StORMdebug { print("StORM Debug: \(statement) : \(params.joined(separator: ", "))") }
	}

	/// Populates a MongoDatabase object with the required connector information.
	/// Returns the new MongoDatabase Object.
	public func setupObject(_ db: String = "") throws -> MongoKitten.Database {
		var usedb = db
		if usedb.isEmpty { usedb = _database }
		do {
            if MongoDBStORM.client == nil {
                let clientSettings = ClientSettings(host: MongoHost(hostname: MongoDBConnection.host, port: MongoDBConnection.port),
                                                    sslSettings: SSLSettings(enabled: MongoDBConnection.ssl),
                                                    credentials: MongoCredentials(username: MongoDBConnection.username, password: MongoDBConnection.password),
                                                    maxConnectionsPerServer: 20)

                MongoDBStORM.client = try Server(clientSettings)
            }

            let client = MongoDBStORM.client!


            let database = client[usedb]
			return database
		} catch {
			throw error
		}
	}

	/// Populates a MongoCollection object with the required connector information.
	/// Returns the new MongoCollection Object.
	public func setupCollection(_ db: String = "") throws -> MongoCollection {
		var usedb = db
		if usedb.isEmpty { usedb = _database }
		do {
            if MongoDBStORM.client == nil {
                let clientSettings = ClientSettings(host: MongoHost(hostname: MongoDBConnection.host, port: MongoDBConnection.port),
                                                    sslSettings: SSLSettings(enabled: MongoDBConnection.ssl),
                                                    credentials: MongoCredentials(username: MongoDBConnection.username, password: MongoDBConnection.password),
                                                    maxConnectionsPerServer: 20)

                MongoDBStORM.client = try Server(clientSettings)
            }


            let database = MongoDBStORM.client![usedb]
            let collection = database[_collection]

			return collection
		} catch {
			throw error
		}
	}

	/// Generic "to" function
	/// Defined as "open" as it is meant to be overridden by the child class.
	///
	/// Sample usage:
	///		id				= this.data["id"] as? String ?? ""
	///		firstname		= this.data["firstname"] as? String ?? ""
	///		lastname		= this.data["lastname"] as? String ?? ""
	///		email			= this.data["email"] as? String ?? ""
	open func to(_ this: StORMRow) {
	}

	/// Generic "makeRow" function
	/// Defined as "open" as it is meant to be overridden by the child class.
	open func makeRow() {
		guard self.results.rows.count > 0 else {
			return
		}
		self.to(self.results.rows[0])
	}



	/// Standard "Save" function.
	/// Designed as "open" so it can be overriden and customized.
	/// If an ID has been defined, save() will perform an update, otherwise a new document is created.
	/// On error can throw a StORMError error.
	@discardableResult
	open func save() throws {
		do {
			let collection = try setupCollection()
            var bson = try Document(extendedJSON: try asDataDict(1).jsonEncodedString())
			if !keyIsEmpty() {
				let (_, idval) = firstAsKey()
				bson.append("\(idval)", forKey: "_id")
			}

            do {
                if let id = bson.dictionaryValue["_id"] as? String {
                    let query: Query = "_id" == id
                    try collection.update(matching: query, to: bson, upserting: true)
                } else {
                    try collection.insert(bson)
                }
            } catch let error {
                LogFile.critical("MongoDB Save error \(error)")
                throw StORMError.error("MongoDB Save error \(error)")
            }
		} catch {
			throw StORMError.error("\(error)")
		}
	}

	/// Collection Creation
	/// This Setup is empty because MongoDB will create the collection automatically when you first try to store data with it
	/// Override this to create your own with c=validation rules etc, as needed.
	@discardableResult
	open func setup() throws {}

	public func newUUID() -> String {
		let x = asUUID()
		return x.string
	}
	struct asUUID {
		let uuid: uuid_t

		public init() {
			let u = UnsafeMutablePointer<UInt8>.allocate(capacity:  MemoryLayout<uuid_t>.size)
			defer {
				u.deallocate(capacity: MemoryLayout<uuid_t>.size)
			}
			uuid_generate_random(u)
			self.uuid = asUUID.uuidFromPointer(u)
		}

		public init(_ string: String) {
			let u = UnsafeMutablePointer<UInt8>.allocate(capacity:  MemoryLayout<uuid_t>.size)
			defer {
				u.deallocate(capacity: MemoryLayout<uuid_t>.size)
			}
			uuid_parse(string, u)
			self.uuid = asUUID.uuidFromPointer(u)
		}

		init(_ uuid: uuid_t) {
			self.uuid = uuid
		}

		private static func uuidFromPointer(_ u: UnsafeMutablePointer<UInt8>) -> uuid_t {
			// is there a better way?
			return uuid_t(u[0], u[1], u[2], u[3], u[4], u[5], u[6], u[7], u[8], u[9], u[10], u[11], u[12], u[13], u[14], u[15])
		}

		public var string: String {
			let u = UnsafeMutablePointer<UInt8>.allocate(capacity:  MemoryLayout<uuid_t>.size)
			let unu = UnsafeMutablePointer<Int8>.allocate(capacity:  37) // as per spec. 36 + null
			defer {
				u.deallocate(capacity: MemoryLayout<uuid_t>.size)
				unu.deallocate(capacity: 37)
			}
			var uu = self.uuid
			memcpy(u, &uu, MemoryLayout<uuid_t>.size)
			uuid_unparse_lower(u, unu)
			return String(validatingUTF8: unu)!
		}
	}

}


