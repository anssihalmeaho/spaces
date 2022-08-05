
ns spaces

# creates new spaces instance
new-spaces = proc()
	import valuez
	import stdvar
	import stdfu
	import evenz

	open-ok open-err db = call(valuez.open 'storespaces'):

	# factory for creating new space
	new-space = proc(spacename)
		open-col = proc()
			ok1 err1 colvalue = call(valuez.get-col db spacename):
			if( ok1
				list(ok1 err1 colvalue)
				call(valuez.new-col db spacename)
			)
		end

		col-ok col-err col = call(open-col):
		puts-ch = chan()
		take-ch = chan()
		take-nw-ch = chan()
		read-ch = chan()
		close-ch = chan()

		# listener API support (by using evenz)
		es = call(evenz.new-evenz)
		publish = get(es 'publish')
		new-es-listener = get(es 'new-listener')

		# fiber for dealing new values for takers/readers
		_ = spawn(call(proc()
			take-waiters = call(stdvar.new list())
			read-waiters = call(stdvar.new list())

			# puts item to space
			do-puts = proc(val)
				# next inform read waiters
				rl = call(stdvar.value read-waiters)
				rmatcher = func(v) real-matcher _ = v: call(real-matcher val) end
				takens remains = call(take-all-matching rl rmatcher):
				_ = call(stdvar.set read-waiters remains)

				readers-notify = proc(ritem _)
					_ target-ch = ritem:
					send(target-ch val)
				end

				_ = call(stdfu.ploop readers-notify takens 'none')

				# then handle take waiters
				wl = call(stdvar.value take-waiters)
				matcher = func(v) real-matcher _ = v: call(real-matcher val) end
				retv = call(take-matching wl matcher)
				is-any item new-takewl = retv:
				_ = if( is-any
					call(proc()
						# notify listeners
						_ = call(publish list('added' val))
						_ = call(publish list('taken' val))

						_ = call(stdvar.set take-waiters new-takewl)
						_ targ-ch = item:
						send(targ-ch list(true val))
					end)
					call(proc()
						added-ok _ = call(valuez.put-value col val):
						# notify listeners
						if(added-ok call(publish list('added' val)) 'value adding failed')
					end)
				)
				true
			end

			# takes item from space
			do-take = proc(item)
				matcher replych = item:
				taken-items = call(valuez.take-values col matcher)
				_ = case( len(taken-items)
					0   call(proc()
							_ = call(stdvar.change take-waiters func(w) append(w item) end)
							'none'
						end)

					1   call(proc()
							val = head(taken-items)
							_ = call(publish list('taken' val))
							send(replych list(true val))
						end)

					call(proc()
						val = head(taken-items)
						_ = call(publish list('taken' val))

						# put leftovers back to store, workaround for not being
						# able to take just one item from there...
						writer = proc(v) call(valuez.put-value col v) end
						_ = call(stdfu.ploop writer rest(taken-items) 'none')

						send(replych list(true val))
					end)
				)
				true
			end

			# takes item from space (no waiting)
			do-take-nw = proc(item)
				matcher replych = item:
				taken-items = call(valuez.take-values col matcher)
				case( len(taken-items)
					0   send(replych list(false ''))

					1   call(proc()
							val = head(taken-items)
							_ = call(publish list('taken' val))
							send(replych list(true val))
						end)

					call(proc()
						val = head(taken-items)
						_ = call(publish list('taken' val))

						# put leftovers back to store, workaround for not being
						# able to take just one item from there...
						writer = proc(v) call(valuez.put-value col v) end
						_ = call(stdfu.ploop writer rest(taken-items) 'none')

						send(replych list(true val))
					end)
				)
			end

			# add reader to wait items
			do-read = proc(item)
				_ = call(stdvar.change read-waiters func(w) append(w item) end)
				true
			end

			# close space
			do-close = proc()
				# to be implemented...
				false
			end

			# receive requests
			call(proc()
				while(
					select(
						puts-ch    do-puts
						take-ch    do-take
						take-nw-ch do-take-nw
						read-ch    do-read
						close-ch   do-close
					)
					'none'
				)
			end)
		end))

		# method for putting value to space
		puts = proc(val)
			send(puts-ch val)
		end

		# method for taking value from space
		take = proc(matcher)
			replych = chan()
			if( send(take-ch list(matcher replych))
				recv(replych)
				list(false '')
			)
		end

		# method for taking value from space, no blocking
		take-nw = proc(matcher)
			# NOTE. this could be done directly to valuez but not
			#       because taken values cannot be restricted to one currently
			replych = chan()
			if( send(take-nw-ch list(matcher replych))
				recv(replych)
				list(false '')
			)
		end

		# method for reading matching value from space
		read = proc(matcher)
			replych = chan()
			if( send(read-ch list(matcher replych))
				recv(replych)
				list()
			)
		end

		# method for reading all current values from space, no blocking
		read-all = proc(matcher)
			call(valuez.get-values col matcher)
		end

		# listener API for space
		new-listener = proc(matcher eventhandler)
			call(new-es-listener matcher eventhandler)
		end

		# close space
		close = proc()
			'Not Implemented'
		end

		# return space -object
		space-ob = if(col-ok
			map(
				'puts'         puts
				'take'         take
				'read'         read
				'take-nw'      take-nw
				'read-all'     read-all
				'new-listener' new-listener
				'close'        close
			)
			map()
		)
		list(col-ok col-err space-ob)
	end

	# close spaces
	sclose = proc()
		'Not Implemented'
	end

	# return spaces -object
	result-ob = if( open-ok
		map(
			'new-space' new-space
			'close'    sclose
		)
		map()
	)
	list(open-ok open-err result-ob)
end

take-matching = func(waiters matcher)
	loop = func(l newlist)
		if( empty(l)
			list(false '' newlist)

			call(func()
				nextv = head(l)
				if( call(matcher nextv)
					list(true nextv append(newlist rest(l):))
					call(loop rest(l) append(newlist nextv))
				)
			end)
		)
	end

	call(loop waiters list())
end

take-all-matching = func(waiters matcher)
	loop = func(l takens remains)
		if( empty(l)
			list(takens remains)

			call(func()
				nextv = head(l)
				if( call(matcher nextv)
					call(loop rest(l) append(takens nextv) remains)
					call(loop rest(l) takens append(remains nextv))
				)
			end)
		)
	end

	call(loop waiters list() list())
end

# test procedure
# can be executed like: funla -name=test -mod=spaces
test = proc()
	import stdio

	get-matching-tester = proc(matcher l)
		result = call(take-matching l matcher)
		_ = print('result -> ' result)
		result
	end

	test-all-matching-1 = proc()
		l = list('a' 'b' 'c' 'd')
		matcher = func(v) in(list('a' 'c') v) end

		takens remains = call(take-all-matching l matcher):
		_ = call(stdio.printf 'takens: %v, remains: %v \n' takens remains)
		and(
			eq(takens list('a' 'c'))
			eq(remains list('b' 'd'))
		)
	end

	test-all-matching-2 = proc()
		l = list('a' 'b' 'c' 'd')
		matcher = func(v) false end

		takens remains = call(take-all-matching l matcher):
		_ = call(stdio.printf 'takens: %v, remains: %v \n' takens remains)
		and(
			eq(takens list())
			eq(remains l)
		)
	end

	test-all-matching-3 = proc()
		l = list('a' 'b' 'c' 'd')
		matcher = func(v) true end

		takens remains = call(take-all-matching l matcher):
		_ = call(stdio.printf 'takens: %v, remains: %v \n' takens remains)
		and(
			eq(takens l)
			eq(remains list())
		)
	end

	test-all-matching-4 = proc()
		l = list()
		matcher = func(v) true end

		takens remains = call(take-all-matching l matcher):
		_ = call(stdio.printf 'takens: %v, remains: %v \n' takens remains)
		and(
			eq(takens l)
			eq(remains l)
		)
	end

	test-get-matching-1 = proc()
		l = list('A' 'b' 'C')
		matcher = func(v) in(list('A' 'C') v) end

		found val l2 = call(get-matching-tester matcher l):
		and(
			found
			eq(val 'A')
			eq(l2 list('b' 'C'))
		)
	end

	test-get-matching-2 = proc()
		l = list('A' 'b' 'C')
		matcher = func(v) false end

		found val l2 = call(get-matching-tester matcher l):
		and(
			not(found)
			eq(val '')
			eq(l2 l)
		)
	end

	test-get-matching-3 = proc()
		l = list('A' 'b' 'C')
		matcher = func(v) eq('C' v) end

		found val l2 = call(get-matching-tester matcher l):
		and(
			found
			eq(val 'C')
			eq(l2 list('A' 'b'))
		)
	end

	test-get-matching-4 = proc()
		l = list('0' 'A' 'b' 'C' 'D')
		matcher = func(v) eq('b' v) end

		found val l2 = call(get-matching-tester matcher l):
		and(
			found
			eq(val 'b')
			eq(l2 list('0' 'A' 'C' 'D'))
		)
	end

	test-get-matching-5 = proc()
		l = list('A')
		matcher = func(v) eq('A' v) end

		found val l2 = call(get-matching-tester matcher l):
		and(
			found
			eq(val 'A')
			eq(l2 list())
		)
	end

	test-get-matching-6 = proc()
		l = list('x' 'A' 'b' 'A' 'C' 'b')
		matcher = func(v) in(list('A' 'C') v) end

		found val l2 = call(get-matching-tester matcher l):
		and(
			found
			eq(val 'A')
			eq(l2 list('x' 'b' 'A' 'C' 'b'))
		)
	end

	tests = list(
		test-all-matching-1
		test-all-matching-2
		test-all-matching-3
		test-all-matching-4

		test-get-matching-1
		test-get-matching-2
		test-get-matching-3
		test-get-matching-4
		test-get-matching-5
		test-get-matching-6
	)

	import stdfu
	result = call(stdfu.ploop proc(t res) and(res call(t)) end tests true)
	if(result 'PASSED' 'FAILED')
end

endns

