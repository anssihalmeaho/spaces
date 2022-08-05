
ns main

import spaces
import stdtime
import stdfu
import stdio

_ _ spaces = call(spaces.new-spaces):
_ _ space = call(get(spaces 'new-space') 'fast-food-restaurant'):

puts = get(space 'puts')
take = get(space 'take')
take-nw = get(space 'take-nw')
new-listener = get(space 'new-listener')

# if true then all events in space are printed
trace-printing-on = false

# any-matcher matches to anything
any-matcher = func() true end

create-matcher = func(event-type)
	func(event)
		evtype = head(event)
		eq(evtype event-type)
	end
end

# observer listens to all events in space
# and prints those if tracing is set on
observer = proc(event)
	_ = if(trace-printing-on print('TRACE: ' event) 'none')
	true
end

# fiber which receives customer orders and puts
# orders with order number to space
orders-receiver = proc()
	import stdvar

	order-num-gen = call(stdvar.new 123)
	request-matcher = call(create-matcher 'meal-request')

	make-order= proc()
		_ _ next-number = call(stdvar.change order-num-gen func(cnt) plus(cnt 1) end):
		got-any event = call(take request-matcher):
		_ = if( got-any
			call(proc()
				_ meal = event:
				_ = call(stdio.printf '%s ordered, order number is %d\n' meal next-number)
				call(puts list('meal-ordered' next-number meal))
			end)
			'no events taken'
		)
		true
	end

	call(proc()
		while(call(make-order) 'none')
	end)
end

# worker is fiber which takes orders and prepares meal
# and after it's ready puts meal-ready event (with order number)
worker = proc()
	order-matcher = call(create-matcher 'meal-ordered')

	get-order = proc()
		got-any event = call(take order-matcher):
		_ = if( got-any
			call(proc()
				_ order-number meal = event:
				_ = call(stdio.printf '...preparing meal: %s ...\n' meal)
				_ = call(stdtime.sleep 1) # some delay to simulate preparing
				call(puts list('meal-ready' order-number))
			end)
			'none'
		)
		true
	end

	call(proc()
		while(call(get-order) 'none')
	end)
end

# ready-viewer shows/prints order-numbers which are ready
# for customer to take
ready-viewer = proc()
	ready-matcher = call(create-matcher 'meal-ready')

	view-ready = proc()
		got-any event = call(take ready-matcher):
		_ = if( got-any
			call(proc()
				_ order-number = event:
				call(stdio.printf 'Order %d is Ready \n' order-number)
			end)
			'none'
		)
		true
	end

	call(proc()
		while(call(view-ready) 'none')
	end)
end

# takes everything away from space
consume-everything = proc()
	consume-item = proc()
		found val = call(take-nw any-matcher):
		_ = if(found print('consume: ' val) 'no items left')
		found
	end

	while(call(consume-item) 'none')
end

main = proc()
	# take all possibly remaining items from space
	_ = call(consume-everything)

	# create observer for tracing all events in space
	observer-ob = call(new-listener any-matcher observer)
	_ = spawn(call(get(observer-ob 'listen')))

	# create orders receivers
	_ = spawn(call(orders-receiver))

	# create workers
	_ = list(
		spawn(call(worker))
		spawn(call(worker))
		spawn(call(worker))
	)

	# create ready viewer (shows order-number which are ready)
	_ = spawn(call(ready-viewer))

	# do some requests as customer with some delays in between
	_ = list(
		call(stdtime.sleep 1)
		call(puts list('meal-request' 'Cheese Burger'))
		call(stdtime.sleep 1)
		call(puts list('meal-request' 'Chicken Burger Meal'))

		call(stdtime.sleep 1)
		call(puts list('meal-request' 'Mega Burger'))
		call(puts list('meal-request' 'Super Burger'))
		call(puts list('meal-request' 'Super Burger'))

		call(stdtime.sleep 4)
	)

	# take all possibly remaining items from space
	_ = call(consume-everything)
	true
end

endns

