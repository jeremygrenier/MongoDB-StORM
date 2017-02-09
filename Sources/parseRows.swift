//
//  parseRows.swift
//  PostgresStORM
//
//  Created by Jonathan Guthrie on 2016-10-06.
//
//

import StORM
import MongoKitten
import PerfectLib
import Foundation

/// Supplies the parseRows method extending the main CouchDBStORM class.
extension MongoDBStORM {

	/// parseRows takes the [String:Any] result and returns an array of StormRows 
	public func parseRows(_ result: MongoKitten.Cursor<Document>) throws -> [StORMRow] {

		var resultRows = [StORMRow]()

		for i in result {
			let thisRow = StORMRow()
			thisRow.data = i.dictionaryValue
			resultRows.append(thisRow)
		}
		
		return resultRows
	}
}
