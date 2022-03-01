#include "ComponentsRegistry.h"

#include <CoreComponentsRegistry.h>

#include <fbjni/fbjni.h>

#include <react/renderer/componentregistry/ComponentDescriptorProviderRegistry.h>
#include <react/renderer/componentregistry/ComponentDescriptorRegistry.h>
#include <react/renderer/components/rncore/ComponentDescriptors.h>

using facebook::react::ComponentDescriptorParameters;
using facebook::react::ComponentDescriptorProviderRegistry;
using facebook::react::ComponentDescriptorRegistry;
using facebook::react::ComponentFactory;
using facebook::react::ContextContainer;
using facebook::react::CoreComponentsRegistry;
using facebook::react::EventDispatcher;
using facebook::react::UnimplementedNativeViewComponentDescriptor;
using ReactTestApp::ComponentsRegistry;

void ComponentsRegistry::registerNatives()
{
    registerHybrid({makeNativeMethod("initHybrid", ComponentsRegistry::initHybrid)});
}

ComponentsRegistry::ComponentsRegistry(ComponentFactory *)
{
}

facebook::jni::local_ref<ComponentsRegistry::jhybriddata>
ComponentsRegistry::initHybrid(facebook::jni::alias_ref<jclass>, ComponentFactory *delegate)
{
    delegate->buildRegistryFunction = [](EventDispatcher::Weak const &eventDispatcher,
                                         ContextContainer::Shared const &contextContainer)
        -> ComponentDescriptorRegistry::Shared {
        auto providerRegistry = CoreComponentsRegistry::sharedProviderRegistry();

        auto registry = providerRegistry->createComponentDescriptorRegistry(
            {eventDispatcher, contextContainer});

        auto mutableRegistry = std::const_pointer_cast<ComponentDescriptorRegistry>(registry);

        mutableRegistry->setFallbackComponentDescriptor(
            std::make_shared<UnimplementedNativeViewComponentDescriptor>(
                ComponentDescriptorParameters{eventDispatcher, contextContainer, nullptr}));

        return registry;
    };

    return makeCxxInstance(delegate);
}
