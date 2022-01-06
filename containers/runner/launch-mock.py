#!/usr/bin/python3

import time
import sys

finish_after_number_of_tests = 999999999
time_consumed_by_test = 0


if __name__ == "__main__":

    if len(sys.argv) > 2:
        time_consumed_by_test = float(sys.argv[2])
    if len(sys.argv) > 1:
        finish_after_number_of_tests = int(sys.argv[1])

    test_is_running = False
    number_of_tests = 0
    with open("./containers/runner/kstest.413.daily-iso.log.txt") as f:
        for line in f:
            if line.startswith("INFO: RESULT"):
                if time_consumed_by_test:
                    time.sleep(time_consumed_by_test)
                number_of_tests += 1
            print(line.strip())
            if number_of_tests == finish_after_number_of_tests:
                break
