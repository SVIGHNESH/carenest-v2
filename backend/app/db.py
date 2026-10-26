from collections.abc import AsyncIterator

from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.orm import DeclarativeBase
from sqlalchemy.pool import NullPool

from app.config import settings


class Base(DeclarativeBase):
    pass


def make_engine(url: str | None = None, null_pool: bool | None = None):
    use_null = settings.DB_NULL_POOL if null_pool is None else null_pool
    kwargs = {"poolclass": NullPool} if use_null else {"pool_size": 5, "max_overflow": 5, "pool_pre_ping": True}
    return create_async_engine(url or settings.DATABASE_URL, **kwargs)


engine = make_engine()
SessionLocal = async_sessionmaker(engine, expire_on_commit=False)


async def get_db() -> AsyncIterator[AsyncSession]:
    async with SessionLocal() as session:
        yield session
