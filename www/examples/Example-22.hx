import utest.Assert;
import utest.ITest;
import utest.Runner;
import utest.ui.Report;

class Test {
	static function main() {
		var tests:Array<ITest> = [new MyTests()];
		var runner:Runner = new Runner();

		Report.create(runner);
		for (test in tests) {
			runner.addCase(test);
		}
		runner.run();
	}
}

class MyTests implements ITest {
	var myVal:String;
	var myInt:Int;

	public function new() {}

	public function setup() {
		myVal = "foo";
		myInt = 1 + 1;
	}

	/* Every test function name has to start with 'test' */
	public function testValue() {
		Assert.equals("foo", myVal);
	}

	public function testMath1() {
		Assert.isTrue(myInt == 2);
	}

	public function testMath2() {
		Assert.isFalse(myInt == 3);
	}
}
