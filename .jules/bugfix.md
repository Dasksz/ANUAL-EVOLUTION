2025/02/06 - Bugfix: Positivação Salty Dashboard Boxes

Learning: Aggregating distinct customers strictly over specific months inside a grouped subquery first, and then summing those individual month counts together, will inflate the final value if a customer bought in multiple months. Calculating distinct count with conditional expressions mapping exactly the filtered period avoids duplication and preserves correctness when month logic is unselected ('todos').

Action: Updated `get_boxes_dashboard_data` function in `sql/full_system_v1.sql` to calculate Positivação Salty KPI using a `LEFT JOIN LATERAL` aggregating the `vlvenda` across the period by `codcli`, resolving the inflated totals and returning proper values even without a month filter.
