
# Ensure WickedPdf uses the wkhtmltopdf binary we extracted to /tmp. This is
# a pragmatic local fix; for production bake the binary into the image at
# /usr/local/bin and update the path accordingly.
# Only configure WickedPdf if the gem is available. This allows the app to run
# in environments where the gem (and wkhtmltopdf binary) were intentionally
# removed to reduce slug/image size.
exe = ENV['WKHTMLTOPDF_PATH'].presence

if exe.blank? || !File.exist?(exe)
	begin
		exe = Gem.bin_path('wkhtmltopdf-binary', 'wkhtmltopdf')
	rescue Gem::Exception
		exe = nil
	end
end

if exe.blank? || !File.exist?(exe)
	fallback_paths = [
		'/usr/local/bin/wkhtmltopdf',
		'/usr/bin/wkhtmltopdf',
		'/usr/local/bundle/ruby/3.4.0/bin/wkhtmltopdf',
		'/app/bin/wkhtmltopdf'
	]
	exe = fallback_paths.find { |path| File.exist?(path) }
end

# Export env for any subprocesses that may inspect it
ENV['WKHTMLTOPDF_PATH'] = exe if exe.present?

if defined?(WickedPdf)
	WickedPdf.config ||= {}
	WickedPdf.config[:exe_path] = exe if exe.present?
	WickedPdf.config[:layout] = 'pdf'

	unless exe.present?
		Rails.logger.warn '[wicked_pdf] wkhtmltopdf executable not found; PDF downloads will fail until configured.'
	end
end
# config/initializers/wicked_pdf.rb
