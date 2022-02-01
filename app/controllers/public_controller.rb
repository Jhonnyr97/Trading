class PublicController < ApplicationController
  def home
    @budget = Transaction.all.map(&:amount).inject(0) { |sum, x| sum + x }
    @btc_quantity = Transaction.all.map(&:quantity).inject(0) { |sum, x| sum + x }
    @btc_value = currency_value
    @total_value = @budget + @btc_value
    @transaction_all = Transaction.all
  end
  private

  def currency_value
    data_response = Binance::Api.ticker!(symbol: 'BTCUSDT', type: :price)
    puts quantity = Transaction.all.map(&:quantity).inject(0) { |sum, x| sum + x }
    puts data_response[:price]
    quantity.to_f * data_response[:price].to_f
  end
end
