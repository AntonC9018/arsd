/**
	jsvar provides a D type called 'var' that works similarly to the same in Javascript.

	It is weakly and dynamically typed, but interops pretty easily with D itself:

	var a = 10;
	a ~= "20";
	assert(a == "1020");

	var a = function(int b, int c) { return b+c; };
	// note the second set of () is because of broken @property
	assert(a()(10,20) == 30);

	var a = var.emptyObject;
	a.foo = 30;
	assert(a["foo"] == 30);

	var b = json!q{
		"foo":12,
		"bar":{"hey":[1,2,3,"lol"]}
	};

	assert(b.bar.hey[1] == 2);


	You can also use var.fromJson, a static method, to quickly and easily
	read json or var.toJson to write it.

	Also, if you combine this with my new arsd.script module, you get pretty
	easy interop with a little scripting language that resembles a cross between
	D and Javascript - just like you can write in D itself using this type.
*/
module arsd.jsvar;

import std.stdio;
import std.traits;
import std.conv;
import std.json;

/*
	PrototypeObject FIXME:
		make undefined variables reaction overloadable in PrototypeObject, not just a switch

	script FIXME:

	the Expression should keep scriptFilename and lineNumber around for error messages

	it should consistently throw on missing semicolons

	*) nesting comments, `` string literals
	*) properties???//
		a.prop on the rhs => a.prop()
		a.prop on the lhs => a.prop(rhs);
		if opAssign, it can just do a.prop(a.prop().opBinary!op(rhs));

		But, how do we mark properties in var? Can we make them work this way in D too?
	0) add global functions to the object like assert()
	1) ensure operator precedence is sane
	2) a++ would prolly be nice, and def -a
	3) loops (foreach - preferably about as well as D (int ranges, arrays, objects with opApply overloaded, and input ranges), do while?)
		foreach(i; 1 .. 10) -> for(var i = 1; i < 10; i++)
		foreach(i; array) -> for(var i = 0; i < array.length; i++)
		foreach(i; object) -> for(var v = new object.iterator; !v.empty(); v.popFront()) { var i = v.front(); / *...* / }
	4) switches?
	6) explicit type conversions somehow (cast?)
	10) __FILE__ and __LINE__ as default function arguments should work like in D
	16) stack traces on script exceptions
	17) an exception type that we can create in the script

	14) import???????/ it could just attach a particular object to the local scope, and the module decl just giving the local scope a name
		there could be a super-global object that is the prototype of the "global" used here
		then you import, and it pulls moduleGlobal.prototype = superGlobal.modulename... or soemthing.

		to get the vars out in D, you'd have to be aware of this, since you pass the superglobal
		hmmm maybe not worth it

		though maybe to export vars there could be an explicit export namespace or something.


	6) gotos? labels? labeled break/continue?
	18) what about something like ruby's blocks or macros? parsing foo(arg) { code } is easy enough, but how would we use it?

	try is considered a statement right now and this only works on top level surrounded by {}
	it should be usable anywhere

	var FIXME:

	user defined operator overloading on objects, including opCall
	flesh out prototype objects for Array, String, and Function

	opEquals and stricterOpEquals
	opDispatch overriding

	it would be nice if delegates on native types could work
*/


/*
	Script notes:

	the one type is var. It works just like the var type in D from arsd.jsvar.
	(it might be fun to try to add other types, and match D a little better here! We could allow implicit conversion to and from var, but not on the other types, they could get static checking. But for now it is only var. BTW auto is an alias for var right now)

	There is no comma operator, but you can use a scope as an expression: a++, b++; can be written as {a++;b++;}
*/

version(test_script)
	struct Foop {
		int a = 12;
		string n = "hate";
		void speak() { writeln(n, " ", a); n = "love"; writeln(n, " is what it is now"); }
		void speak2() { writeln("speak2 ", n, " ", a); }
	}
version(test_script)
void main() {
	// the WrappedNativeObject is disgusting
	// but works.
	/*
	Foop foop2;

	var foop;
	foop._object = new WrappedNativeObject!Foop(foop2);

	foop.speak()();
	foop.a = 25;
	writeln(foop.n);
	foop.speak2()();
	return;
	*/

	import arsd.script;
	struct Test {
		int a = 10;
		string name = "ten";
	}

	auto globals = var.emptyObject;
	globals.lol = 100;
	globals.rofl = 23;

	globals.arrtest = var.emptyArray;

	globals.write._function = (var _this, var[] args) {
		string s;
		foreach(a; args)
			s ~= a.get!string;
		writeln("script said: ", s);
		return var(null);
	};

	// call D defined functions in script
	globals.func =  (var a, var b) { writeln("Hello, world! You are : ", a, " and ", b); };

	globals.ex = () { throw new ScriptRuntimeException("test", 1); };

	globals.fun = { return var({ writeln("hello inside!"); }); };

	import std.file;
	writeln(interpret(readText("scripttest_code.d"), globals));

	globals.ten = 10.0;
	globals.five = 5.0;
	writeln(interpret(q{
		var a = json!q{ };
		a.b = json!q{ };
		a.b.c = 10;
		a;
	}, globals));

	repl(globals);

	writeln("BACK IN D!");
	globals.c()(10); // call script defined functions in D (note: this runs the interpreter)

	//writeln(globals._getMember("lol", false));
	return;

	var k,l ;

	var j = json!q{
		"hello": {
			"data":[1,2,"giggle",4]
		},
		"world":20
	};

	writeln(j.hello.data[2]);


	Test t;
	var rofl = t;
	writeln(rofl.name);
	writeln(rofl.a);

	rofl.a = "20";
	rofl.name = "twenty";

	t = rofl.get!Test;
	writeln(t);

	var a1 = 10;
	a1 -= "5";
	a1 /= 2;

	writeln(a1);

	var a = 10;
	var b = 20;
	a = b;

	b = 30;
	a += 100.2;
	writeln(a);

	var c = var.emptyObject;
	c.a = b;

	var d = c;
	d.b = 50;

	writeln(c.b);

	writeln(d.toJson());

	var e = a + b;
	writeln(a, " + ", b, " = ", e);

	e = function(var lol) {
		writeln("hello with ",lol,"!");
		return lol + 10;
	};

	writeln(e("15"));

	if(var("ass") > 100)
		writeln(var("10") / "3");
}

template json(string s) {
	// ctfe doesn't support the unions std.json uses :(
	//enum json = var.fromJsonObject(s);

	// FIXME we should at least validate string s at compile time
	var json() {
		return var.fromJson("{" ~ s ~ "}");
	}
}

private real stringToNumber(string s) {
	real r;
	try {
		r = to!real(s);
	} catch (Exception e) {
		r = real.nan;
	}

	return r;
}

private bool realIsInteger(real r) {
	return (r == cast(long) r);
}

// helper template for operator overloading
private var _op(alias _this, alias this2, string op, T)(T t) if(op == "~") {
	static if(is(T == var)) {
		if(t.payloadType() == var.Type.Array)
			return _op!(_this, this2, op)(t._payload._array);
		else if(t.payloadType() == var.Type.String)
			return _op!(_this, this2, op)(t._payload._string);
		//else
			//return _op!(_this, this2, op)(t.get!string);
	}

	if(this2.payloadType() == var.Type.Array) {
		auto l = this2._payload._array;
		static if(isArray!T && !isSomeString!T)
			foreach(item; t)
				l ~= var(item);
		else
			l ~= var(t);

		_this._type = var.Type.Array;
		_this._payload._array = l;
		return _this;
	} else if(this2.payloadType() == var.Type.String) {
		auto l = this2._payload._string;
		l ~= var(t).get!string; // is this right?
		_this._type = var.Type.String;
		_this._payload._string = l;
		return _this;
	} else {
		auto l = this2.get!string;
		l ~= var(t).get!string;
		_this._type = var.Type.String;
		_this._payload._string = l;
		return _this;
	}

	assert(0);

}

// FIXME: maybe the bitops should be moved out to another function like ~ is
private var _op(alias _this, alias this2, string op, T)(T t) if(op != "~") {
	static if(is(T == var)) {
		if(t.payloadType() == var.Type.Integral)
			return _op!(_this, this2, op)(t._payload._integral);
		if(t.payloadType() == var.Type.Floating)
			return _op!(_this, this2, op)(t._payload._floating);
		if(t.payloadType() == var.Type.String)
			return _op!(_this, this2, op)(t._payload._string);
		assert(0, to!string(t.payloadType()));
	} else {
		if(this2.payloadType() == var.Type.Integral) {
			auto l = this2._payload._integral;
			static if(isIntegral!T) {
				mixin("l "~op~"= t;");
				_this._type = var.Type.Integral;
				_this._payload._integral = l;
				return _this;
			} else static if(isFloatingPoint!T) {
				static if(op == "&" || op == "|" || op == "^") {
					this2._type = var.Type.Integral;
					long f = l;
					mixin("f "~op~"= cast(long) t;");
					_this._type = var.Type.Integral;
					_this._payload._integral = f;
				} else {
					this2._type = var.Type.Floating;
					real f = l;
					mixin("f "~op~"= t;");
					_this._type = var.Type.Floating;
					_this._payload._floating = f;
				}
				return _this;
			} else static if(isSomeString!T) {
				auto rhs = stringToNumber(t);
				if(realIsInteger(rhs)) {
					mixin("l "~op~"= cast(long) rhs;");
					_this._type = var.Type.Integral;
					_this._payload._integral = l;
				} else{
					static if(op == "&" || op == "|" || op == "^") {
						long f = l;
						mixin("f "~op~"= cast(long) rhs;");
						_this._type = var.Type.Integral;
						_this._payload._integral = f;
					} else {
						real f = l;
						mixin("f "~op~"= rhs;");
						_this._type = var.Type.Floating;
						_this._payload._floating = f;
					}
				}
				return _this;

			}
		} else if(this2.payloadType() == var.Type.Floating) {
			auto f = this._payload._floating;

			static if(isIntegral!T || isFloatingPoint!T) {
				static if(op == "&" || op == "|" || op == "^") {
					long argh = cast(long) f;
					mixin("argh "~op~"= cast(long) t;");
					_this._type = var.Type.Integral;
					_this._payload._integral = argh;
				} else {
					mixin("f "~op~"= t;");
					_this._type = var.Type.Floating;
					_this._payload._floating = f;
				}
				return _this;
			} else static if(isSomeString!T) {
				auto rhs = stringToNumber(t);

				static if(op == "&" || op == "|" || op == "^") {
					long pain = cast(long) f;
					mixin("pain "~op~"= cast(long) rhs;");
					_this._type = var.Type.Integral;
					_this._payload._floating = pain;
				} else {
					mixin("f "~op~"= rhs;");
					_this._type = var.Type.Floating;
					_this._payload._floating = f;
				}
				return _this;
			} else assert(0);
		} else if(this2.payloadType() == var.Type.String) {
			static if(op == "&" || op == "|" || op == "^") {
				long r = cast(long) stringToNumber(this2._payload._string);
				long rhs;
			} else {
				real r = stringToNumber(this2._payload._string);
				real rhs;
			}

			static if(isSomeString!T) {
				rhs = cast(typeof(rhs)) stringToNumber(t);
			} else {
				rhs = to!(typeof(rhs))(t);
			}

			mixin("r " ~ op ~ "= rhs;");

			static if(is(typeof(r) == real)) {
				_this._type = var.Type.Floating;
				_this._payload._floating = r;
			} else static if(is(typeof(r) == long)) {
				_this._type = var.Type.Integral;
				_this._payload._integral = r;
			} else static assert(0);
			return _this;
		} else {
			// the operation is nonsensical, we should throw or ignore it
			var i = 0;
			return i;
		}
	}

	assert(0);
}


struct var {
	public this(T)(T t) {
		static if(is(T == var))
			this = t;
		else
			this.opAssign(t);
	}

	public var _copy() {
		final switch(payloadType()) {
			case Type.Integral:
			case Type.Boolean:
			case Type.Floating:
			case Type.Function:
			case Type.String:
				// since strings are immutable, we can pretend they are value types too
				return this; // value types don't need anything special to be copied

			case Type.Array:
				var cp;
				cp = this._payload._array[];
				return cp;
			case Type.Object:
				var cp;
				if(this._payload._object !is null)
					cp._object = this._payload._object.copy;
				return cp;
		}
	}

	public bool opCast(T:bool)() {
		final switch(this._type) {
			case Type.Object:
				return this._payload._object !is null;
			case Type.Array:
				return this._payload._array.length != 0;
			case Type.String:
				return this._payload._string.length != 0;
			case Type.Integral:
				return this._payload._integral != 0;
			case Type.Floating:
				return this._payload._floating != 0;
			case Type.Boolean:
				return this._payload._boolean;
			case Type.Function:
				return this._payload._function !is null;
		}
	}

	public int opApply(int delegate(ref var) dg) {
		if(this.payloadType() == Type.Array)
			foreach(ref v; this._payload._array)
				if(auto result = dg(v))
					return result;
		return 0;
	}

	public T opCast(T)() {
		return this.get!T;
	}

	public auto ref putInto(T)(ref T t) {
		return t = this.get!T;
	}

	// if it is var, we'll just blit it over
	public var opAssign(T)(T t) if(!is(T == var)) {
		static if(isFloatingPoint!T) {
			this._type = Type.Floating;
			this._payload._floating = t;
		} else static if(isIntegral!T) {
			this._type = Type.Integral;
			this._payload._integral = t;
		} else static if(isCallable!T) {
			this._type = Type.Function;
			this._payload._function = delegate var(var _this, var[] args) {
				var ret;

				ParameterTypeTuple!T fargs;
				foreach(idx, a; fargs) {
					if(idx == args.length)
						break;
					cast(Unqual!(typeof(a))) fargs[idx] = args[idx].get!(typeof(a));
				}

				static if(is(ReturnType!t == void)) {
					t(fargs);
				} else {
					ret = t(fargs);
				}

				return ret;
			};
		} else static if(isSomeString!T) {
			this._type = Type.String;
			this._payload._string = to!string(t);
		} else static if((is(T == class) || is(T == struct) || isAssociativeArray!T)) {
			this,_type = Type.Object;
			auto obj = new PrototypeObject();
			this._payload._object = obj;

			foreach(member; __traits(allMembers, T)) {
				static if(__traits(compiles, __traits(getMember, t, member))) {
					static if(is(typeof(__traits(getMember, t, member)) == function)) {
						// skipping these because the delegate we get isn't going to work anyway; the object may be dead and certainly won't be updated
						//this[member] = &__traits(getMember, proxyObject, member);
					} else
						this[member] = __traits(getMember, t, member);
				}
			}
		} else static if(isArray!T) {
			this._type = Type.Array;
			var[] arr;
			arr.length = t.length;
			foreach(i, item; t)
				arr[i] = var(item);
			this._payload._array = arr;
		} else static if(is(T == bool)) {
			this._type = Type.Boolean;
			this._payload._boolean = t;
		}

		return this;
	}

	public var opOpAssign(string op, T)(T t) {
		if(payloadType() == Type.Object) {
			var operator = this["opOpAssign"];
			if(operator._type == Type.Function)
				return operator.call(this, op, t);
		}

		return _op!(this, this, op, T)(t);
	}

	public var opBinary(string op, T)(T t) {
		var n;
		if(payloadType() == Type.Object) {
			var operator = this["opBinary"];
			if(operator._type == Type.Function) {
				return operator.call(this, op, t);
			}
		}
		return _op!(n, this, op, T)(t);
	}

	public var apply(var _this, var[] args) {
		if(this.payloadType() == Type.Function) {
			return this._payload._function(_this, args);
		}

		// or we could throw
		var ret;
		return ret;
	}

	public var call(T...)(var _this, T t) {
		var[] args;
		foreach(a; t) {
			args ~= var(a);
		}
		return this.apply(_this, args);
	}

	public var opCall(T...)(T t) {
		return this.call(this, t);
	}

	public string toString() {
		return this.get!string;
	}

	public T get(T)() {
		static if(is(T == var)) {
			return this;
		} else
		final switch(payloadType) {
			case Type.Boolean:
				static if(is(T == bool))
					return this._payload._boolean;
				else static if(isFloatingPoint!T || isIntegral!T)
					return this._payload._boolean ? 1 : 0;
				else static if(isSomeString!T)
					return this._payload._boolean ? "true" : "false";
				else
				return T.init;
			case Type.Object:
				static if(isAssociativeArray!T) {
					T ret;
					foreach(k, v; this._properties)
						ret[to!(KeyType!T)(k)] = v.get!(ValueType!T);

					return ret;
				} else static if(is(T == struct) || is(T == class)) {
					T t;
					static if(is(T == class))
						t = new T();

					foreach(i, a; t.tupleof) {
						cast(Unqual!(typeof((a)))) t.tupleof[i] = this[t.tupleof[i].stringof[2..$]].get!(typeof(a));
					}

					return t;
				} else static if(isSomeString!T) {
					// FIXME: is this best?
					return this.toJson();
				}

				return T.init;
			case Type.Integral:
				static if(isFloatingPoint!T || isIntegral!T)
					return to!T(this._payload._integral);
				else static if(isSomeString!T)
					return to!string(this._payload._integral);
				else
					return T.init;
			case Type.Floating:
				static if(isFloatingPoint!T || isIntegral!T)
					return to!T(this._payload._floating);
				else static if(isSomeString!T)
					return to!string(this._payload._floating);
				else
					return T.init;
			case Type.String:
				static if(__traits(compiles, to!T(this._payload._string)))
					try {
						return to!T(this._payload._string);
					} catch (Exception e) {}
				return T.init;
			case Type.Array:
				auto pl = this._payload._array;
				static if(isSomeString!T) {
					return to!string(pl);
				} else static if(isArray!T) {
					T ret;
					foreach(item; pl)
						ret ~= item.get!(ElementType!T);
					return ret;
				}

				// is it sane to translate anything else?

				return T.init;
			case Type.Function:
				static if(isSomeString!T)
					return "<function>";
				// FIXME: we just might be able to do better for both of these
				return T.init;
			//break;
		}
	}

	public int opCmp(T)(T t) {
		auto f = this.get!real;
		static if(is(T == var))
			auto r = t.get!real;
		else
			auto r = t;
		return cast(int)(f - r);
	}

	public bool opEquals(T)(T t) {
		return this.opEquals(var(t));
	}


	public bool opEquals(T:var)(T t) {
		// FIXME: should this be == or === ?
		if(this._type != t._type)
			return false;
		final switch(this._type) {
			case Type.Object:
				return _payload._object is t._payload._object;
			case Type.Integral:
				return _payload._integral == t._payload._integral;
			case Type.Boolean:
				return _payload._boolean == t._payload._boolean;
			case Type.Floating:
				return _payload._floating == t._payload._floating; // FIXME: approxEquals?
			case Type.String:
				return _payload._string == t._payload._string;
			case Type.Function:
				return _payload._function is t._payload._function;
			case Type.Array:
				return _payload._array == t._payload._array;
		}
		assert(0);
	}

	public enum Type {
		Object, Array, Integral, Floating, String, Function, Boolean
	}

	public Type payloadType() {
		return _type;
	}

	private Type _type;

	// FIXME: arrays, functions, and strings are supposed to have prototypes too
	private union Payload {
		PrototypeObject _object;
		var[] _array;
		long _integral;
		real _floating;
		string _string;
		bool _boolean;
		var delegate(var _this, var[] args) _function;
	}

	public void _function(var delegate(var, var[]) f) {
		this._payload._function = f;
		this._type = Type.Function;
	}

	public void _object(PrototypeObject obj) {
		this._type = Type.Object;
		this._payload._object = obj;
	}

	package Payload _payload;

	private void _requireType(Type t, string file = __FILE__, size_t line = __LINE__){
		if(this.payloadType() != t)
			throw new DynamicTypeException(this, t, file, line);
	}

	public var opSlice(var e1, var e2) {
		return this.opSlice(e1.get!ptrdiff_t, e2.get!ptrdiff_t);
	}

	public var opSlice(ptrdiff_t e1, ptrdiff_t e2) {
		if(this.payloadType() == Type.Array) {
			if(e1 > _payload._array.length)
				e1 = _payload._array.length;
			if(e2 > _payload._array.length)
				e2 = _payload._array.length;
			return var(_payload._array[e1 .. e2]);
		}
		if(this.payloadType() == Type.String) {
			if(e1 > _payload._string.length)
				e1 = _payload._string.length;
			if(e2 > _payload._string.length)
				e2 = _payload._string.length;
			return var(_payload._string[e1 .. e2]);
		}
		if(this.payloadType() == Type.Object) {
			var operator = this["opSlice"];
			if(operator._type == Type.Function) {
				return operator.call(this, e1, e2);
			}
		}

		// might be worth throwing here too
		return var(null);
	}

	public @property ref var opDispatch(string name, string file = __FILE__, size_t line = __LINE__)() {
		return this[name];
	}

	public @property ref var opDispatch(string name, string file = __FILE__, size_t line = __LINE__, T)(T r) {
		return this.opIndexAssign!T(r, name);
	}

	public ref var opIndex(var name, string file = __FILE__, size_t line = __LINE__) {
		return opIndex(name.get!string, file, line);
	}

	public ref var opIndexAssign(T)(T t, var name, string file = __FILE__, size_t line = __LINE__) {
		return opIndexAssign(t, name.get!string, file, line);
	}

	public ref var opIndex(string name, string file = __FILE__, size_t line = __LINE__) {
		// if name is numeric, we should convert to int
		if(name.length && name[0] >= '0' && name[0] <= '9')
			return opIndex(to!size_t(name), file, line);

		if(this.payloadType() != Type.Object && name == "prototype")
			return prototype();

		if(name == "typeof") {
			var* tmp = new var;
			*tmp = to!string(this.payloadType());
			return *tmp;
		}

		if(name == "length" && this.payloadType() == Type.String) {
			var* tmp = new var;
			*tmp = _payload._string.length;
			return *tmp;
		}
		if(name == "length" && this.payloadType() == Type.Array) {
			var* tmp = new var;
			*tmp = _payload._array.length;
			return *tmp;
		}

		PrototypeObject from;
		if(this.payloadType() == Type.Object)
			from = _payload._object;
		else {
			var pt = this.prototype();
			assert(pt.payloadType() == Type.Object);
			from = pt._payload._object;
		}

		if(from is null)
			throw new DynamicTypeException(var(null), Type.Object, file, line);
		return from._getMember(name, true, false, file, line);
	}

	public ref var opIndexAssign(T)(T t, string name, string file = __FILE__, size_t line = __LINE__) {
		if(name.length && name[0] >= '0' && name[0] <= '9')
			return opIndexAssign(t, to!size_t(name), file, line);
		_requireType(Type.Object); // FIXME?
		if(_payload._object is null)
			throw new DynamicTypeException(var(null), Type.Object, file, line);

		this._payload._object._getMember(name, false, false, file, line) = t;
		return this._payload._object._properties[name];
	}

	public ref var opIndex(size_t idx, string file = __FILE__, size_t line = __LINE__) {
		if(_type == Type.Array) {
			auto arr = this._payload._array;
			if(idx < arr.length)
				return arr[idx];
		}
		var* n = new var();
		return *n;
	}

	public ref var opIndexAssign(T)(T t, size_t idx, string file = __FILE__, size_t line = __LINE__) {
		if(_type == Type.Array) {
			alias arr = this._payload._array;
			if(idx >= this._payload._array.length)
				this._payload._array.length = idx + 1;
			this._payload._array[idx] = t;
			return this._payload._array[idx];
		}
		var* n = new var();
		return *n;
	}

	ref var _getOwnProperty(string name, string file = __FILE__, size_t line = __LINE__) {
		if(_type == Type.Object) {
			if(_payload._object !is null)
				return this._payload._object._getMember(name, false, false, file, line);
		}
		var* n = new var();
		return *n;
	}

	@property static var emptyObject(PrototypeObject prototype = null) {
		var v;
		v._type = Type.Object;
		v._payload._object = new PrototypeObject();
		v._payload._object.prototype = prototype;
		return v;
	}

	// what I call prototype is more like what Mozilla calls __proto__, but tbh I think this is better so meh
	@property ref var prototype() {
		static var _arrayPrototype;
		static var _functionPrototype;
		static var _stringPrototype;


		final switch(payloadType()) {
			case Type.Array:
				assert(_arrayPrototype._type == Type.Object);
				if(_arrayPrototype._payload._object is null) {
					_arrayPrototype._object = new PrototypeObject();
					writeln("ctor on ", payloadType());
				}

				return _arrayPrototype;
			break;
			case Type.Function:
				assert(_functionPrototype._type == Type.Object);
				if(_functionPrototype._payload._object is null) {
					_functionPrototype._object = new PrototypeObject();
				}

				return _functionPrototype;
			break;
			case Type.String:
				assert(_stringPrototype._type == Type.Object);
				if(_stringPrototype._payload._object is null) {
					_stringPrototype._object = new PrototypeObject();
				}

				return _stringPrototype;
			break;
			case Type.Object:
				if(_payload._object)
					return _payload._object._prototype;
				// FIXME: should we do a generic object prototype?
			break;
			case Type.Integral:
			case Type.Floating:
			case Type.Boolean:
				// these types don't have prototypes
		}

		var* v = new var(null);
		return *v;
	}

	@property static var emptyArray() {
		var v;
		v._type = Type.Array;
		return v;
	}

	// FIXME
	static var fromJson(string json) {
		auto decoded = parseJSON(json);
		return var.fromJsonValue(decoded);
	}

	static var fromJsonValue(JSONValue v) {
		var ret;

		final switch(v.type) {
			case JSON_TYPE.STRING:
				ret = v.str;
			break;
			case JSON_TYPE.UINTEGER:
				ret = v.uinteger;
			break;
			case JSON_TYPE.INTEGER:
				ret = v.integer;
			break;
			case JSON_TYPE.FLOAT:
				ret = v.floating;
			break;
			case JSON_TYPE.OBJECT:
				ret = var.emptyObject;
				foreach(k, val; v.object) {
					ret[k] = var.fromJsonValue(val);
				}
			break;
			case JSON_TYPE.ARRAY:
				ret = var.emptyArray;
				ret._payload._array.length = v.array.length;
				foreach(idx, item; v.array) {
					ret._payload._array[idx] = var.fromJsonValue(item);
				}
			break;
			case JSON_TYPE.TRUE:
				ret = true;
			break;
			case JSON_TYPE.FALSE:
				ret = false;
			break;
			case JSON_TYPE.NULL:
				ret = null;
			break;
		}

		return ret;
	}

	string toJson() {
		auto v = toJsonValue();
		return toJSON(&v);
	}

	// FIXME: maybe we could do some cool stuff with boolean true/false and uinteger too
	JSONValue toJsonValue() {
		JSONValue val;
		final switch(payloadType()) {
			case Type.Boolean:
				if(this._payload._boolean)
					val.type = JSON_TYPE.TRUE;
				else
					val.type = JSON_TYPE.FALSE;
			break;
			case Type.Object:
				if(_payload._object is null) {
					val.type = JSON_TYPE.NULL;
				} else {
					val.type = JSON_TYPE.OBJECT;
					foreach(k, v; _payload._object._properties)
						val.object[k] = v.toJsonValue();
				}
			break;
			case Type.String:
				val.type = JSON_TYPE.STRING;
				val.str = _payload._string;
			break;
			case Type.Integral:
				val.type = JSON_TYPE.INTEGER;
				val.integer = _payload._integral;
			break;
			case Type.Floating:
				val.type = JSON_TYPE.FLOAT;
				val.floating = _payload._floating;
			break;
			case Type.Array:
				val.type = JSON_TYPE.ARRAY;

				auto a = _payload._array;
				val.array.length = a.length;
				foreach(i, v; a) {
					val.array[i] = v.toJsonValue();
				}
			break;
			case Type.Function:
				val.type = JSON_TYPE.NULL; // ideally we would just skip it entirely...
			break;
		}
		return val;
	}
}

class WrappedNativeObject(T, bool wrapData = true) : PrototypeObject {
	T nativeObject;


	auto makeWrapper(string member)() {
		return (var _this, var[] args) {
			auto func = &(__traits(getMember, nativeObject, member));
			var ret;

			// this is a filthy hack and i hate it
			// the problem with overriding getMember though is we can't really control what happens when it is set, since that's all done through the ref, and we don't want to overload stuff there since it can be copied.
			// so instead on each method call, I'll copy the data from the prototype back out... and then afterward, copy from the object back to the prototype. gross.

			// first we need to make sure that the native object is updated...
			static if(wrapData)
				updateNativeObject();



			ParameterTypeTuple!(__traits(getMember, nativeObject, member)) fargs;
			foreach(idx, a; fargs) {
				if(idx == args.length)
					break;
				cast(Unqual!(typeof(a))) fargs[idx] = args[idx].get!(Unqual!(typeof(a)));
			}

			static if(is(ReturnType!func == void)) {
				func(fargs);
			} else {
				ret = func(fargs);
			}


			// then transfer updates from it back here
			static if(wrapData)
				getUpdatesFromNativeObject();

			return ret;
		};
	}


	this(T t) {
		this.name = T.stringof;
		this.nativeObject = t;
		// this.prototype = new PrototypeObject();

		foreach(member; __traits(allMembers, T)) {
			static if(__traits(compiles, __traits(getMember, nativeObject, member))) {
				static if(is(typeof(__traits(getMember, nativeObject, member)) == function)) {
					this._getMember(member, false, false)._function =
						makeWrapper!(member)();
				} else static if(wrapData)
					this._getMember(member, false, false) = __traits(getMember, nativeObject, member);
			}
		}
	}

	void updateNativeObject() {
		foreach(member; __traits(allMembers, T)) {
			static if(__traits(compiles, __traits(getMember, nativeObject, member))) {
				static if(is(typeof(__traits(getMember, nativeObject, member)) == function)) {
					// ignore, if these are overridden, we want it to stay that way
				} else {
					// if this doesn't compile, it is prolly cuz it is const or something
					static if(__traits(compiles, this._getMember(member, false, false).putInto(__traits(getMember, nativeObject, member))))
						this._getMember(member, false, false).putInto(__traits(getMember, nativeObject, member));
				}
			}
		}
	}

	void getUpdatesFromNativeObject() {
		foreach(member; __traits(allMembers, T)) {
			static if(__traits(compiles, __traits(getMember, nativeObject, member))) {
				static if(is(typeof(__traits(getMember, nativeObject, member)) == function)) {
					// ignore, these won't change
				} else {
					this._getMember(member, false, false) = __traits(getMember, nativeObject, member);
				}
			}
		}
	}

	override WrappedNativeObject!T copy() {
		auto n = new WrappedNativeObject!T(nativeObject);
		// FIXME: what if nativeObject is a reference type?
		return n;
	}
}

class PrototypeObject {
	string name;
	var _prototype;

	PrototypeObject prototype() {
		if(_prototype.payloadType() == var.Type.Object)
			return _prototype._payload._object;
		return null;
	}

	PrototypeObject prototype(PrototypeObject set) {
		this._prototype._object = set;
		return set;
	}

	var[string] _properties;

	PrototypeObject copy() {
		auto n = new PrototypeObject();
		n.prototype = this.prototype;
		n.name = this.name;
		foreach(k, v; _properties) {
			n._properties[k] = v._copy;
		}
		return n;
	}

	// FIXME: maybe throw something else
	/*package*/ ref var _getMember(string name, bool recurse, bool throwOnFailure, string file = __FILE__, size_t line = __LINE__) {
		if(name == "prototype")
			return _prototype;

		auto curr = this;
		do {
			auto prop = name in curr._properties;
			if(prop is null) {
				if(!recurse)
					break;
				else
					curr = curr.prototype;
			} else
				return *prop;
		} while(curr);

		// if we're here, the property was not found, so let's implicitly create it
		if(throwOnFailure)
			throw new Exception("no such property " ~ name, file, line);
		var n;
		this._properties[name] = n;
		return this._properties[name];
	}
}


class DynamicTypeException : Exception {
	this(var v, var.Type required, string file = __FILE__, size_t line = __LINE__) {
		import std.string;
		if(v.payloadType() == required)
			super(format("Tried to use null as a %s", required), file, line);
		else
			super(format("Tried to use %s as a %s", v.payloadType(), required), file, line);
	}
}
