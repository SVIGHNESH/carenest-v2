class BookingError(Exception):
    """A rule was broken. `code` is stable for the apps; `message` is shown to people."""

    def __init__(self, code: str, message: str, status: int = 400):
        super().__init__(message)
        self.code = code
        self.message = message
        self.status = status
