
import asyncio
import io
import time

import pytest
from conftest import page

@pytest.mark.asyncio
async def test_navigation(page):
    await page.goto("http://localhost:8080/index.html")
    # Add navigation assertions here when appropriate
    assert await page.title() == "Painel de Vendas - PRIME v7.0 (Supabase)"
