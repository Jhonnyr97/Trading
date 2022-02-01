class BinanceWorker
  include Sidekiq::Worker

  def perform(*args)
    create_datum symbol: 'BTCUSDT'
    execute!(index: 5)
  end

  private

  def execute!(index: nil)
    # average_change_force = difference_price
    # if Transaction.count >= 2
    #   last_change_force = different_values(difference_price, average_change_force.last, percentage: false)
    # elsif average_change_force.count >= 3
    #   average_differences = sum_values(average_change_force, remove_last: true)
    #   last_change_force = different_values(average_differences, average_change_force.last, percentage: false)
    # else
    #   return
    # end
    return unless Datum.count >= 1

    average_differences = difference_price
    last_change_force = 0
    unless Transaction.where.not(type_action: :charging).where.not(type_action: :withdraw).count >= 2
      average_change_force = average_change(index: 16)
      last_change_force = different_values(difference_price, average_change_force.last, percentage: false)
    end
    if Transaction.where.not(type_action: :charging).where.not(type_action: :withdraw).count >= 2
      last_change_force = different_values(average_differences, Datum.last.price, percentage: false)
    end
    puts '-' * 100
    puts 'execute'
    puts '-' * 100
    puts last_change_force
    select_transaction(last_change_force)
  end

  def select_transaction(last_change_force)
    type_action, final_value = nil
    if last_change_force&.positive?
      total_value = value_quantity(quantity: select_quantity)
      final_value = value_by_percentage(quantity: total_value, change_force: last_change_force)
      type_action = :sell
      final_value = value_by_percentage(quantity: total_value, change_force: 100) unless can_sell?(final_value)
    elsif last_change_force
      final_value = value_by_percentage(quantity: select_amount, change_force: last_change_force)
      type_action = :buy
      final_value = value_by_percentage(quantity: select_amount, change_force: -100) unless can_buy?(final_value)
    end
    puts transaction(amount: final_value, type_action: type_action) if final_value.abs > 10
    puts "Value is very low: #{final_value}" unless final_value.abs > 10
  end

  def can_buy?(amount_sell)
    amount_sell.abs < select_amount
  end

  def can_sell?(amount_buy)
    quantity_for_sell = quantity_by_amount(amount: amount_buy.abs)
    select_quantity > quantity_for_sell
  end

  def transaction(amount: 0, type_action: nil)
    quantity_price = quantity_by_amount(amount: amount)
    quantity_price = -quantity_price if type_action == :sell
    price = current_price('BTCUSDT')
    transaction = Transaction.create!(amount: amount, quantity: quantity_price, type_action: type_action, price: price)
    puts "Amount: #{transaction.amount}, Quantity: #{transaction.quantity}, Type: #{transaction.type_action}"
  end

  def buy_all
    select_amount
  end

  def sell_all
    value_quantity(quantity: select_quantity)
  end

  def select_quantity
    Transaction.all.map(&:quantity).inject(0) { |sum, x| sum + x }
  end

  def select_amount
    Transaction.all.map(&:amount).inject(0) { |sum, x| sum + x }
  end

  def value_by_percentage(quantity: nil, change_force: nil)
    change_force.to_f / 100 * quantity.to_f
  end

  def average_change(index: 0)
    a = nil
    b = nil
    averages = []
    Datum.last(index).each_with_index do |data, i|
      i.even? ? a = data.price : b = data.price
      averages.push(different_values(a, b)) if a.present? && b.present?
    end
    averages
  end

  def difference_price
    if Transaction.where.not(type_action: :charging).where.not(type_action: :withdraw).count >= 2
      average_value_quantity = []
      average_value_price = []
      Transaction.where.not(type_action: :charging).where.not(type_action: :withdraw).each do |transaction|
        average_value_quantity.push(value_quantity(quantity: transaction.quantity))
        average_value_price.push(transaction.price * value_quantity(quantity: transaction.quantity))
      end

      final_quantity = average_value_quantity.inject(0) { |sum, x| sum + x } / average_value_quantity.count
      final_price = average_value_price.inject(0) { |sum, x| sum + x } / average_value_quantity.count

      final_price / final_quantity
    else
      current_price('BTCUSDT')
    end
  end

  def create_datum(symbol: 'BTCUSDT')
    Binance::Api::Configuration.api_key = ENV['BINANCE_API_KEY']
    Binance::Api::Configuration.secret_key = ENV['BINANCE_SECRET_KEY']
    data_response = binance_ticker(symbol)
    Datum.create!(symbol: data_response[:symbol], price: data_response[:price])
  end

  def binance_ticker(symbol)
    Binance::Api.ticker!(symbol: symbol, type: :price)
  end

  def current_price(symbol)
    data_response = Binance::Api.ticker!(symbol: symbol, type: :price)
    data_response[:price].to_f
  end

  def different_values(initial_value, final_value, percentage: true)
    calculate = ((final_value - initial_value) / initial_value)
    calculate *= 100 if percentage
    calculate
  end

  def value_quantity(quantity: 0)
    quantity * Datum.last.price
  end

  def quantity_by_amount(amount: 0.0)
    amount.abs / Datum.last.price
  end

  def sum_values(values, remove_last: nil)
    values.pop if remove_last
    result_sum = values.inject(0) { |sum, x| sum + x }
    result_sum /= values.count if result_sum != 0
    result_sum
  end
end

