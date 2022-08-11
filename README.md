# spaces
tuplespace for FunL

**Tuplespace** is old model of computing in which there's shared repository
to which concurrent "processes" can put and get values ("tuples").
This model provides loose coupling between value producers and consumers.
It can serve as workflow synchronizing method and it is providing
messaging/event mechanism simultaneously with value storage.

Sometimes this model is also related to **blackboard metaphor**
in which several concurrent actors apply their expertise
via shared "blackboard" in order to come up with some solution.

**spaces** is tuplespace kind of implementation for [FunL programming language](https://github.com/anssihalmeaho/funl).

**spaces** works in context one process so that concurrency happens between several fibers.
Values are stored to permanent storage if it's not consumed rightaway.
**valuez** value store is used as permanent storage.

**spaces** object (created with __spaces.new-spaces__ procedure) has following methods:

* **new-space**: creates new **space** object
* **close**: closes spaces (**NOT IMPLEMENTED YET**)

Many **space** objects can be created under one **spaces** object.

There are just few basic primitives which are applied for **space**:

* **puts**: puts value to space
* **take**: takes value from space (matched by given function), blocks if needed
* **take-nw**: same as **take** but is non-blocking version
* **read**: read next new value in space (matched by given function), blocks until next matching value is available
* **read-all**: read all matching values which are currently in space
* **new-listener**: creates new listener (for listening space changes)
* **close**: closes space (**NOT IMPLEMENTED YET**)

Values which are put to **space** need to be [serializable in FunL](https://github.com/anssihalmeaho/funl/wiki/stdser).

# APIs

## new-spaces
Creates new **spaces** -object.

format:

```
call(spaces.new-spaces) -> spaces object (map)
```

**spaces** -object (__map__) has following methods:

| Key | Value |
| --- | ----- |
| 'new-space' | space object factory method (procedure) |
| 'close' | method closes spaces (**NOT IMPLEMENTED YET**) |

### new-space method
Creates new **space** object.

format:

```
call(new-space <space-name:string>) -> space object (map)
```

### space object

**space** -object (__map__) has following methods:

| Key | Value |
| --- | ----- |
| 'puts' | puts value to space (procedure) |
| 'take' | takes value from space, blocks if needed (procedure) |
| 'take-nw' | same as 'take' but is non-blocking version (procedure) |
| 'read' | read next new value in space, blocks (procedure) |
| 'read-all' | read all matching values which are currently in space (procedure) |
| 'new-listener' | creates new listener object (for listening space changes) (procedure) |
| 'close' | method closes spaces (**NOT IMPLEMENTED YET**) |


#### puts method
Puts value to space.
If there's some fiber waiting to take that value then it's given there,
otherwise value is added **valuez** value store.

format:

```
call(puts <value>) -> true
```

#### take method
Takes value from space, blocks until matched value is found.
Matcher function is given as argument.

Matcher function gets value from space as argument
returns **true** if it's matching, **false** otherwise.

Matcher function format is:

```
func(<value>) -> bool
```

format:

```
call(take <matcher:func>) -> list(<is-any:bool> <value>)
```

Return value is list:

1. bool: **true** if value was taken from space, **false** otherwise.
2. value from space

#### take-nw method
Similar to as take -method but is non-blocking version.
Doesn't remain waiting for matching values to come to space.

format:

```
call(take-nw <matcher:func>) -> list(<is-any:bool> <value>)
```

Return value is list:

1. bool: **true** if value was taken from space, **false** otherwise.
2. value from space

#### read method
Reads next new value in space (matched by function given as argument).
Blocks until next matching value is available.

format:

```
call(read <matcher:func>) -> <value>
```

#### read-all method
Read all matching values which are currently in space.
Returns list of values.

format:

```
call(read-all <matcher:func>) -> list(<value>, ...)
```

#### new-listener method
Creates space listener object (__map__).

Listener interface provides way to listen actions (changes) happening in space.

Events are list values of following kind:

* __list('added' <value>)__: value is added to space
* __list('taken' <value>)__: value is taken from space

Actual listener interface is using [evenz](https://github.com/anssihalmeaho/evenz) API.

format:

```
call(new-listener <matcher:func> <handler:proc>) -> listener object
```

See details how to listener object (__map__) from [evenz documentation](https://github.com/anssihalmeaho/evenz).


# Get started

Prerequisite is to have [FunL interpreter](https://github.com/anssihalmeaho/funl) compiled.

**spaces** uses **valuez** value store and that need to be taken into use as described
in [ValueZ Install](https://github.com/anssihalmeaho/fuvaluez).

After having FunL interpreter build clone **spaces** from Github:

```
git clone https://github.com/anssihalmeaho/spaces
```


# Examples
Example code can be found in [/examples/burger_restaurant_example.fnl](https://github.com/anssihalmeaho/spaces/blob/main/examples/burger_restaurant_example.fnl).
It simulates Hamburger Restaurant workflow from order to completed meal.
Separate phases of meal preparation are triggered by adding and taking values from **space**.
Separate phases are implemented in separate fibers loosely coupled via shared space.

When running that with __funla__ interpreter it should output something like:

```
./funla spaces/examples/burger_restaurant_example.fnl

Cheese Burger ordered, order number is 124
...preparing meal: Cheese Burger ...
Order 124 is Ready
Chicken Burger Meal ordered, order number is 125
...preparing meal: Chicken Burger Meal ...
Order 125 is Ready
Mega Burger ordered, order number is 126
...preparing meal: Mega Burger ...
Super Burger ordered, order number is 127
...preparing meal: Super Burger ...
Super Burger ordered, order number is 128
...preparing meal: Super Burger ...
Order 127 is Ready
Order 126 is Ready
Order 128 is Ready
true
```
