// Модуль UART
// Рабочая частота: 19200 бод
// Бит данных: 8 штук
// Пероверка чётности: отсутствует
// Стоп-бит: 1 штука
// Передача происходит чуть медленнее, чем приём (для недёжности), поэтому
//  сделать из него простую "петлю" без буфера не получится.

module uart (
	output [7:0]RX_DATA, // Принятые данные (receive)
	input [7:0]TX_DATA, // Отправляемые данные (transmit)
	output RXC, // Флаг окончания приёма (transmit complete)
	output TXC, // Флаг окончания передачи (receive complete)
	input TXS, // Команда начала передачи (transmit start)
	input CLOCK_50, // Тактовый сигнал 50 МГц
	input RX, // Входной провод
	output TX // Выходной провод
	);
	
	parameter PERIOD = 16'd2604; // 50 000 000 Гц / 19200 бод = 2604,1(6)

	// --- Приём ---

	reg [7:0]rx_reg; // Принятые данные
	reg [15:0]rx_clock_counter; // Счетчик скорости приёма данных
	reg [3:0]rx_bit_counter; // Счетчик прнятых бит
	
	always @(posedge CLOCK_50)
	begin
		// Делитель для внутреннего тактового сигнала
		rx_clock_counter = rx_clock_counter + 16'd1;
		if (rx_clock_counter >= PERIOD)
		begin
			// Здесь происходит событие переполнения внутреннего счетчика
			rx_clock_counter = 16'd0;

			if (RXC & !RX) // Если предыдущий приём завершился и мы приняли стартовый бит - начинаем новый приём
				rx_bit_counter = 4'd0; // Счетчик принятых битов обнуляем

			if (rx_bit_counter <= 4'd8) // Если предыдущий байт мы еще не приняли полностью
			begin
				if ((rx_bit_counter >= 4'd1) && (rx_bit_counter <= 4'd8)) // Пропускаем старт- и стоп-биты
					rx_reg[rx_bit_counter - 4'd1] = RX; // Запоминаем бит
				rx_bit_counter = rx_bit_counter + 4'd1; // Увеличиваем счетчик битов
			end
		end
	end

	assign RX_DATA = rx_reg; // Результат непрерывно транслируется на выход из модуля
	
	assign RXC = (rx_bit_counter >= 4'd9); // Флаг окончания приёма

	// --- Передача ---

	reg [7:0]tx_reg; // Данные для передачи
	reg [15:0]tx_clock_counter; // Счетчик скорости отправки данных
	reg [3:0]tx_bit_counter; // Счетчик отправленных бит
	
	always @(posedge CLOCK_50)
	begin
		// Делитель для внутреннего тактового сигнала
		tx_clock_counter = tx_clock_counter + 16'd1;
		if (tx_clock_counter >= PERIOD)
		begin
			// Здесь происходит событие переполнения внутреннего счетчика
			tx_clock_counter = 16'd0;

			if (tx_bit_counter <= 4'd10) // Если предыдущий байт еще не передался
					tx_bit_counter = tx_bit_counter + 4'd1; // Увеличиваем счетчик битов
		end
		
		if (TXC & TXS) // Если предыдущая передача завершилась - ожидаем команды "transmit start"
			begin
			tx_reg <= TX_DATA; // Значение входного регистра берётся со входа модуля по тактовому сигналу
			tx_bit_counter <= 4'd0; // Счетчик передачи обнуляем
			tx_clock_counter <= 16'd0; // Обнуляем счетчик времени, чтобы старт-бит удерживался необходимое время
			end
	end
	
	assign TX = // Провод для передачи информации
		(tx_bit_counter <= 4'd0) ? 1'b0 : // Стартовый бит
		(tx_bit_counter >= 4'd9) ? 1'b1 : // Стоп-биты
		tx_reg[tx_bit_counter - 4'd1]; // Данные

	assign TXC = (tx_bit_counter >= 4'd11); // Флаг окончания передачи

endmodule

