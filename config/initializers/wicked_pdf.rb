
# Ensure WickedPdf uses the wkhtmltopdf binary we extracted to /tmp. This is
# a pragmatic local fix; for production bake the binary into the image at
# /usr/local/bin and update the path accordingly.
# Only configure WickedPdf if the gem is available. This allows the app to run
# in environments where the gem (and wkhtmltopdf binary) were intentionally
# removed to reduce slug/image size.
exe = ENV['WKHTMLTOPDF_PATH'].presence || '/tmp/wkhtmltopdf'
# Export env for any subprocesses that may inspect it
ENV['WKHTMLTOPDF_PATH'] = exe

if defined?(WickedPdf)
	WickedPdf.config ||= {}
	WickedPdf.config[:exe_path] = exe
	WickedPdf.config[:layout] = 'pdf'
end
# config/initializers/wicked_pdf.rb
