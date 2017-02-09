//
//  Convenience.swift
//  PostgresStORM
//
//  Created by Jonathan Guthrie on 2016-10-04.
//
//

import StORM
import MongoKitten
import PerfectLogger

/// Convenience methods extending the main CouchDBStORM class.
extension MongoDBStORM {

	/// Deletes one row, with an id
	/// Presumes first property in class is the id.
	public func delete() throws {
		do {
			let (_, idval) = firstAsKey()
			if (idval as! String).isEmpty {
				self.error = StORMError.error("No id specified.")
				throw error
			}

			let collection = try setupCollection()
            let query: Query = "_id" == idval as! String

            do {
                _ = try collection.remove(matching: query)
            } catch let error {
                LogFile.critical("MongoDB Delete error \(error)")
                throw StORMError.error("MongoDB Delete error \(error)")
            }
		} catch {
			self.error = StORMError.error("\(error)")
			throw error
		}
	}

	/// Retrieves a document with a specified ID.
	public func get(_ id: String) throws {
		do {
			let collection = try setupCollection()

            let query: Query = "_id" == id
            if let cursor = (try? collection.find(matching: query, sortedBy: nil, projecting: nil, readConcern: nil, collation: nil, skipping: nil, limitedTo: 1)) ?? nil {
                // convert response into object
                try processResponse(cursor)
            }
        } catch {

            self.error = StORMError.error("\(error)")
            throw error
        }
	}

	/// Retrieves a document with the ID as set in the object.
	public func get() throws {
		let (_, idval) = firstAsKey()
		let xidval = idval as! String
		if xidval.isEmpty { return }
		do {
			try get(idval as! String)
		} catch {
			throw error
		}
	}

    public func find(_ query: MongoKitten.Query? = nil, cursor: StORMCursor = StORMCursor()) throws {
        do {
            let collection = try setupCollection()

            if let objects = (try? collection.find(matching: query)) ?? nil {
                do {
                    try processResponse(objects)
                } catch {
                    throw error
                }
            }
        } catch {
            throw error
        }
    }

	private func processResponse(_ response: Cursor<Document>) throws {
		do {
			try results.rows = parseRows(response)
			results.cursorData.totalRecords = results.rows.count
			if results.cursorData.totalRecords == 1 { makeRow() }
		} catch {
			throw error
		}
	}
}
