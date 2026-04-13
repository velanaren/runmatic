#!/usr/bin/env python3
import asyncio
import sys
sys.path.insert(0, '/app')

from app.auth import get_password_hash
from app.models import User
from app.database import AsyncSessionLocal
from datetime import datetime, timezone

async def create_user():
    async with AsyncSessionLocal() as session:
        user = User(
            email='demo@runmatic.dev',
            hashed_password=get_password_hash('demo1234'),
            created_at=datetime.now(timezone.utc).replace(tzinfo=None)
        )
        session.add(user)
        await session.commit()
        print('User created: demo@runmatic.dev / demo1234')

asyncio.run(create_user())
