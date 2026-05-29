package app.cronwatch.di

import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent

/**
 * Reserved for future @Provides. Most services are constructor-injected
 * `@Singleton` classes and need no module.
 */
@Module
@InstallIn(SingletonComponent::class)
object AppModule
