require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "a list date is as short as possible" do
    travel_to Time.zone.local(2026, 10, 30, 9, 0) do
      assert_equal "8h05", list_time(Time.zone.local(2026, 10, 30, 8, 5))[/>(.*)</, 1]
      assert_equal "hier", list_time(Time.zone.local(2026, 10, 29, 23, 0))[/>(.*)</, 1]
      assert_equal "27 oct.", list_time(Time.zone.local(2026, 10, 27, 15, 13))[/>(.*)</, 1]
      assert_equal "03/12/2025", list_time(Time.zone.local(2025, 12, 3, 10, 0))[/>(.*)</, 1]
      assert_nil list_time(nil)
    end
  end
end
