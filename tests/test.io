#!/usr/local/bin/io

/*
	select 
		op: keys / values | pairs / rm | counts | json
		before:id
		after:id
		count:max
		whereKey:k, whereValue:v
	rm
	mkdir
	link
	chmod
	chown
	stat
	size

	read
	write mode: set / append

	queuePopTo
	queueExpireTo

	transaction
	login
	newUser

	shutdown
	backup
	collectGarbage
	stats
*/

VDBTest := UnitTest clone do(
	setUp := method(
		url := URL with("http://localhost:8080/?action=transaction")
		result := url post("/?action=select&op=rm
/test/a?action=mkdir
/test/a?action=write&key=_a&value=1
/test/a?action=write&key=_b&value=2
/test/a?action=write&key=_c&value=3
/test/b?action=mkdir
/test/b?action=write&key=_a&value=4
/test/b?action=write&key=_b&value=5
/test/b?action=write&key=_c&value=6
/test/c?action=mkdir
/test/c?action=write&key=_a&value=7
/test/c?action=write&key=_b&value=5
/test/c?action=write&key=_c&value=9")
		if(url statusCode == 500,
			Exception raise("Error in transaction setting up VDBTest: " .. result)
		)
	)
	
	VDBAssertion := Object clone do(
		actualBody ::= nil
		expectedBody ::= nil
		actualStatusCode ::= nil
		expectedStatusCode ::= 200
		
		action ::= nil
		variant ::= "default"
		
		baseUrl ::= "http://localhost:8080"
		basePath ::= "/test"
		path ::= ""
		params ::= List clone
		
		with := method(aVariant,
			self clone setVariant(aVariant)
		)
		
		queryString := method(
			str := ("?action=" .. action) asMutable
			if(params size > 0,
				str appendSeq("&") appendSeq(params join("&"))
			)
			str
		)
		
		addParams := method(
			params appendSeq(call evalArgs)
			self
		)
		
		url := method(
			URL with(Sequence with(baseUrl, basePath, path, queryString))
		)
		
		assert := method(
			u := url
			//writeln(u url)
			setActualBody(u fetch)
			setActualStatusCode(u statusCode)
			
			if(actualStatusCode != expectedStatusCode,
				Exception raise(Sequence with(action, " action failed for \"", variant, "\" variant: \n", u url, "\nexpectedStatusCode ", expectedStatusCode asString, "\nactualStatusCode   ", actualStatusCode asString, "\n"))
			)
			
			if(actualBody != expectedBody,
				Exception raise(Sequence with(action, " action failed for \"", variant, "\" variant: \n", "expectedBody ", expectedBody, "\nactualBody   ", actualBody, "\n"))
			)
		)
	)
	
	
	
	ReadAssertion := VDBAssertion clone do(action ::= "read")
	testRead := method(
		ReadAssertion clone setPath("/a") addParams("key=_a") setExpectedBody("\"1\"") assert
		ReadAssertion clone setPath("/a") addParams("key=_b") setExpectedBody("\"2\"") assert
		ReadAssertion clone setPath("/a") addParams("key=_c") setExpectedBody("\"3\"") assert
		ReadAssertion with("missing key") setPath("/a") addParams("key=_d") setExpectedBody("null") assert
		ReadAssertion with("bad path") setPath("/d") addParams("key=_d") setExpectedBody("\"path does not exist: test/d\"") setExpectedStatusCode(500) assert
	)
	
	SelectAssertion := VDBAssertion clone do(
		action ::= "select"
		op ::= nil
		
		queryString := method(
			str := resend
			str .. "&op=" .. op
		)
	)
	
	KeysAssertion ::= SelectAssertion clone do(op ::= "keys")
	
	testSelectKeys := method(
		KeysAssertion clone setExpectedBody("""["a","b","c"]""") assert
		KeysAssertion with("count") addParams("count=1") setExpectedBody("""["a"]""") assert
		KeysAssertion with("after") addParams("after=a") setExpectedBody("""["b","c"]""") assert
		KeysAssertion with("before") addParams("before=b") setExpectedBody("""["a"]""") assert
		KeysAssertion with("where") addParams("whereKey=_b", "whereValue=5") setExpectedBody("""["b","c"]""") assert
		KeysAssertion with("non-matching where") addParams("whereKey=_a", "whereValue=10") setExpectedBody("[]") assert
	)
	
	/*
	testSelectPairs := method(
		actualPairs := URL with("http://localhost:8080/test?action=select&op=pairs") fetch
		expectedPairs := """[["a",{"_a":"1","_b":"2","_c":"3"}],["b",{"_a":"4","_b":"5","_c":"6"}],["c",{"_a":"7","_b":"5","_c":"9"}]]"""
		assertEquals(actualPairs, expectedPairs)
		
		
		actualPairsWithCount := URL with("http://localhost:8080/test?action=select&op=pairs&count=1") fetch
		expectedPairsWithCount := """[["a",{"_a":"1","_b":"2","_c":"3"}]]"""
		assertEquals(actualPairsWithCount, expectedPairsWithCount)
		
		actualPairsWithAfter := URL with("http://localhost:8080/test?action=select&op=pairs&after=a") fetch
		expectedPairsWithAfter := """[["b",{"_a":"4","_b":"5","_c":"6"}],["c",{"_a":"7","_b":"5","_c":"9"}]]"""
		assertEquals(actualPairsWithAfter, expectedPairsWithAfter)
		
		actualPairsWithBefore := URL with("http://localhost:8080/test?action=select&op=pairs&before=b") fetch
		expectedPairsWithBefore := """[["a",{"_a":"1","_b":"2","_c":"3"}]]"""
		assertEquals(actualPairsWithBefore, expectedPairsWithBefore)
		
		actualPairsWithWhere := URL with("http://localhost:8080/test?action=select&op=pairs&whereKey=_b&whereValue=5") fetch
		expectedPairsWithWhere := """[["b",{"_a":"4","_b":"5","_c":"6"}],["c",{"_a":"7","_b":"5","_c":"9"}]]"""
		assertEquals(actualPairsWithWhere, expectedPairsWithWhere)
		
		actualEmptyPairsWithWhere := URL with("http://localhost:8080/test?action=select&op=pairs&whereKey=_a&whereValue=10") fetch
		expectedEmptyPairsWithWhere := """[]"""
		assertEquals(actualEmptyPairsWithWhere, expectedEmptyPairsWithWhere)
	)
	
	testSelectValues := method(
		actualValues := URL with("http://localhost:8080/test?action=select&op=values") fetch
		expectedValues := """[{"_a":"1","_b":"2","_c":"3"},{"_a":"4","_b":"5","_c":"6"},{"_a":"7","_b":"5","_c":"9"}]"""
		assertEquals(actualValues, expectedValues)
		
		
		actualValuesWithCount := URL with("http://localhost:8080/test?action=select&op=values&count=1") fetch
		expectedValuesWithCount := """[{"_a":"1","_b":"2","_c":"3"}]"""
		assertEquals(actualValuesWithCount, expectedValuesWithCount)
		
		actualValuesWithAfter := URL with("http://localhost:8080/test?action=select&op=values&after=a") fetch
		expectedValuesWithAfter := """[{"_a":"4","_b":"5","_c":"6"},{"_a":"7","_b":"5","_c":"9"}]"""
		assertEquals(actualValuesWithAfter, expectedValuesWithAfter)
		
		actualValuesWithBefore := URL with("http://localhost:8080/test?action=select&op=values&before=b") fetch
		expectedValuesWithBefore := """[{"_a":"1","_b":"2","_c":"3"}]"""
		assertEquals(actualValuesWithBefore, expectedValuesWithBefore)
		
		actualValuesWithWhere := URL with("http://localhost:8080/test?action=select&op=values&whereKey=_b&whereValue=5") fetch
		expectedValuesWithWhere := """[{"_a":"4","_b":"5","_c":"6"},{"_a":"7","_b":"5","_c":"9"}]"""
		assertEquals(actualValuesWithWhere, expectedValuesWithWhere)
		
		actualEmptyValuesWithWhere := URL with("http://localhost:8080/test?action=select&op=values&whereKey=_a&whereValue=10") fetch
		expectedEmptyValuesWithWhere := """[]"""
		assertEquals(actualEmptyValuesWithWhere, expectedEmptyValuesWithWhere)
	)
	
	testSelectSizes := method(
		actualSizes := URL with("http://localhost:8080/test?action=select&op=sizes") fetch
		expectedSizes := """{"a":3,"b":3,"c":3}"""
		assertEquals(actualSizes, expectedSizes)
		
		
		actualSizesWithCount := URL with("http://localhost:8080/test?action=select&op=sizes&count=1") fetch
		expectedSizesWithCount := """{"a":3}"""
		assertEquals(actualSizesWithCount, expectedSizesWithCount)
		
		actualSizesWithAfter := URL with("http://localhost:8080/test?action=select&op=sizes&after=a") fetch
		expectedSizesWithAfter := """{"b":3,"c":3}"""
		assertEquals(actualSizesWithAfter, expectedSizesWithAfter)
		
		actualSizesWithBefore := URL with("http://localhost:8080/test?action=select&op=sizes&before=b") fetch
		expectedSizesWithBefore := """{"a":3}"""
		assertEquals(actualSizesWithBefore, expectedSizesWithBefore)
		
		actualSizesWithWhere := URL with("http://localhost:8080/test?action=select&op=sizes&whereKey=_b&whereValue=5") fetch
		expectedSizesWithWhere := """{"b":3,"c":3}"""
		assertEquals(actualSizesWithWhere, expectedSizesWithWhere)
		
		actualEmptySizesWithWhere := URL with("http://localhost:8080/test?action=select&op=sizes&whereKey=_a&whereValue=10") fetch
		expectedEmptySizesWithWhere := """{}"""
		assertEquals(actualEmptySizesWithWhere, expectedEmptySizesWithWhere)
	)
	
	testSelectRm := method(
		actualRm := URL with("http://localhost:8080/test?action=select&op=rm") fetch
		expectedRm := """3"""
		assertEquals(actualRm, expectedRm)
		actualRmPairs := URL with("http://localhost:8080/test?action=select&op=pairs") fetch
		expectedRmPairs := """[]"""
		assertEquals(actualRmPairs, expectedRmPairs)
		setUp
		
		actualRmWithCount := URL with("http://localhost:8080/test?action=select&op=rm&count=1") fetch
		expectedRmWithCount := """1"""
		assertEquals(actualRmWithCount, expectedRmWithCount)
		actualRmWithCountPairs := URL with("http://localhost:8080/test?action=select&op=pairs") fetch
		expectedRmWithCountPairs := """[["b",{"_a":"4","_b":"5","_c":"6"}],["c",{"_a":"7","_b":"5","_c":"9"}]]"""
		assertEquals(actualRmWithCountPairs, expectedRmWithCountPairs)
		setUp
		
		actualRmWithAfter := URL with("http://localhost:8080/test?action=select&op=rm&after=a") fetch
		expectedRmWithAfter := """2"""
		assertEquals(actualRmWithAfter, expectedRmWithAfter)
		actualRmWithAfterPairs := URL with("http://localhost:8080/test?action=select&op=pairs") fetch
		expectedRmWithAfterPairs := """[["a",{"_a":"1","_b":"2","_c":"3"}]]"""
		assertEquals(actualRmWithAfterPairs, expectedRmWithAfterPairs)
		setUp
		
		actualRmWithBefore := URL with("http://localhost:8080/test?action=select&op=rm&before=b") fetch
		expectedRmWithBefore := """1"""
		assertEquals(actualRmWithBefore, expectedRmWithBefore)
		actualRmWithBeforePairs := URL with("http://localhost:8080/test?action=select&op=pairs") fetch
		expectedRmWithBeforePairs := """[["b",{"_a":"4","_b":"5","_c":"6"}],["c",{"_a":"7","_b":"5","_c":"9"}]]"""
		assertEquals(actualRmWithBeforePairs, expectedRmWithBeforePairs)
		setUp
		
		actualRmWithWhere := URL with("http://localhost:8080/test?action=select&op=rm&whereKey=_b&whereValue=5") fetch
		expectedRmWithWhere := """2"""
		assertEquals(actualRmWithWhere, expectedRmWithWhere)
		actualRmWithWherePairs := URL with("http://localhost:8080/test?action=select&op=pairs") fetch
		expectedRmWithWherePairs := """[["a",{"_a":"1","_b":"2","_c":"3"}]]"""
		assertEquals(actualRmWithWherePairs, expectedRmWithWherePairs)
		setUp
		
		actualEmptyRmWithWhere := URL with("http://localhost:8080/test?action=select&op=rm&whereKey=_a&whereValue=10") fetch
		expectedEmptyRmWithWhere := """0"""
		assertEquals(actualEmptySizesWithWhere, expectedEmptySizesWithWhere)
		actualEmptyRmWithWherePairs := URL with("http://localhost:8080/test?action=select&op=pairs") fetch
		expectedEmptyRmWithWherePairs := """[["a",{"_a":"1","_b":"2","_c":"3"}],["b",{"_a":"4","_b":"5","_c":"6"}],["c",{"_a":"7","_b":"5","_c":"9"}]]"""
		assertEquals(actualEmptyRmWithWherePairs, expectedEmptyRmWithWherePairs)
	)
	
	testSelectObject := method(
		actualObject := URL with("http://localhost:8080/test/a?action=select&op=object") fetch
		expectedObject := """{"_a":"1","_b":"2","_c":"3"}"""
		assertEquals(actualObject, expectedObject)
	)
	*/
)

VDBTest run

/*
assertEquals := method(a, b, 
	if(a != b, 
		Exception raise(call message argAt(0) .. " == " .. a .. " instead of " .. b)
	)
)

URL with("http://localhost:8080/?action=select&op=rm") fetch

// test size

assertEquals(URL with("http://localhost:8080/?action=size") fetch, "0")

// test mkdir, write

URL with("http://localhost:8080/test?action=mkdir") fetch
URL with("http://localhost:8080/test?action=write&key=_a") post("1")
URL with("http://localhost:8080/test?action=write&key=_b") post("2")
URL with("http://localhost:8080/test?action=write&key=_c") post("3")

// test read



// test select keys/values



// test select pairs before/after

assertEquals(URL with("http://localhost:8080/test?action=select&op=pairs") fetch, """[["_a","1"],["_b","2"],["_c","3"]]""")
assertEquals(URL with("http://localhost:8080/test?action=select&op=pairs&after=_a") fetch,  """[["_b","2"],["_c","3"]]""")
assertEquals(URL with("http://localhost:8080/test?action=select&op=pairs&before=_c") fetch, """[["_b","2"],["_a","1"]]""")
assertEquals(URL with("http://localhost:8080/test?action=size") fetch, "3")

// test rm

URL with("http://localhost:8080/test?action=rm&key=_a") fetch
//assertEquals(URL with("http://localhost:8080/test?action=read&key=_a") fetch, null)
assertEquals(URL with("http://localhost:8080/test?action=size") fetch, "2")

// test select rm

URL with("http://localhost:8080/test?action=write&key=_a") post("1")
URL with("http://localhost:8080/test?action=select&op=rm&after=_a") fetch
assertEquals(URL with("http://localhost:8080/test?action=size") fetch, "1")

/*
userId := URL with("http://localhost:8080/?newUser") fetch
c1 := URL with("http://localhost:8080/users/" .. userId .. "/items/unseen?count") fetch
c2 := URL with("http://localhost:8080/public/items?count") fetch
assertEquals(c1, c2)
*/

/*
Object squareBrackets := Object getSlot("list")
Object curlyBrackets := Object getSlot("list")
assertEquals(id1, id2)
*/
*/