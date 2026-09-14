# ADR-002: Stage and atomically publish disk images

DMGStudio creates a hidden, unique staging directory beside final output. It builds a writable UDRW image, writes Finder metadata while mounted, converts it to UDZO, verifies it, then moves it into the requested path. Existing output is rejected. This prevents partially generated DMGs from appearing as successful output.
