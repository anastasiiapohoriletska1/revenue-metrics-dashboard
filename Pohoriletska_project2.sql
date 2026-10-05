with monthly_revenue as (
    select
        user_id,
        date_trunc('month', payment_date)::date as month,
        sum(revenue_amount_usd) as revenue
    from project.games_payments
    group by 1, 2
),
user_movement as (
    select
        user_id,
        month,
        revenue,
        lag(month) over (partition by user_id order by month) as previous_paid_month,
        lag(revenue) over (partition by user_id order by month) as previous_month_revenue,
        lead(month) over (partition by user_id order by month) as next_paid_month
    from monthly_revenue
),
revenue_metrics as (
    select
        user_id,
        month,
        revenue as mrr,
        1 as paid_user,
        case
            when previous_paid_month is null
            then revenue else 0
        end as new_mrr,
        case
            when previous_paid_month is null
            then 1 else 0
        end as new_paid_user,
        case
            when previous_paid_month = month - interval '1 month'
                 and revenue > previous_month_revenue
            then revenue - previous_month_revenue else 0
        end as expansion_mrr,
        case
            when previous_paid_month = month - interval '1 month'
                 and revenue < previous_month_revenue
            then previous_month_revenue - revenue else 0
        end as contraction_mrr,
        case
            when next_paid_month is null
                 or next_paid_month > month + interval '1 month'
            then revenue else 0
        end as churned_revenue,
        case
            when next_paid_month is null
                 or next_paid_month > month + interval '1 month'
            then 1 else 0
        end as churned_user,
        case
            when next_paid_month is null
                 or next_paid_month > month + interval '1 month'
            then (month + interval '1 month')::date
            else null
        end as churn_month
    from user_movement
)
select
    rm.*,
    gpu.language,
    gpu.age,
    gpu.game_name
from revenue_metrics rm
left join games_paid_users gpu
    on rm.user_id = gpu.user_id
order by month;

